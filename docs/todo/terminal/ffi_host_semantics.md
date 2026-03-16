# Terminal FFI Host Semantics TODO

## Scope

Define the next class of terminal/host integration signals that should be
available through FFI without turning the bridge into a widget or renderer API.

This lane exists because Zide wants richer host/backend integration than
Ghostty currently exposes, while still keeping the same ownership discipline:

- backend exports structured terminal-derived facts
- host decides how those facts appear in tabs, badges, notifications, chrome,
  overlays, or workspace UI

## Why This Exists

Ghostty is a strong reference for a clean engine/surface split, but it is not a
complete reference for the amount of host-visible state Zide wants.

Examples Zide may eventually want that go beyond Ghostty's current bridge style:

- build/test progress surfaced in tab chips
- command-running / command-finished state
- foreground task classification
- richer shell-integration state
- command-span or prompt-derived host actions
- explicit attention / activity state

The rule should not be "match Ghostty's minimal state surface exactly."
The rule should be:

- keep Ghostty's ownership discipline
- only expose reusable host semantics
- do not expose UI instructions

## Design Rules

- Expose facts, not presentation.
- Prefer structured semantic state over raw desktop-specific hints.
- Keep host-rendering policy out of the bridge.
- Keep native and FFI aligned to the same semantic contract.
- Do not add a field just because native can currently reach it internally.
- Do not encode app-specific tab-chip, badge, or color decisions into the ABI.

## Candidate Semantic Families

- Foreground activity
  - running / idle / exited
  - foreground process classification
  - command currently active
- Progress
  - determinate percentage
  - indeterminate progress
  - progress text label if truly terminal-derived
- Shell integration
  - prompt boundary presence
  - command start / command finish
  - semantic prompt capabilities
- Attention state
  - bell/activity-worthy events
  - task completion worth surfacing
- Host metadata enrichment
  - stronger foreground-process labels
  - cwd/title/task label separation where justified

## Non-Goals

- No tab-chip strings, badge colors, icons, or animation flags.
- No direct "show toast" / "show notification" bridge calls.
- No native-only convenience state that an FFI host cannot consume equally.
- No widening until each semantic family has a clear backend source of truth.

## TODO

- [ ] `FHS-01` Inventory terminal-derived host semantics already available or
  partially available in native code.
- [ ] `FHS-02` Classify which semantics are true backend facts vs host policy.
- [ ] `FHS-03` Define the smallest first enriched host-semantic packet that
  could support progress/activity integration without UI leakage.
- [ ] `FHS-04` Check each candidate against Ghostty, Kitty, and Windows
  Terminal behavior to understand what is terminal-derived vs host-inferred.
- [ ] `FHS-05` Propose how enriched host semantics should travel:
  metadata, event stream, or snapshot-adjacent state.

## Current Inventory Notes

Initial audit, 2026-03-17:

- Already available as backend facts:
  - title
  - cwd
  - alive / child exit status
  - scrollback count / scrollback offset
  - alt-screen state
  - mouse-reporting state
  - foreground-process presence outside the shell
  - Linux-only foreground-process label from the PTY layer
  - semantic prompt state:
    - prompt/input/output activity
    - prompt kind
    - exit code
    - redraw / special-key / click-event flags
- Already exported or partially exported through native/FFI host surfaces:
  - title / cwd
  - alive / child exit
  - close-confirm signals
  - scrollback viewport metadata
- Present in native behavior/tests but not yet a structured host semantic:
  - Zig/std.Progress redraw patterns
  - build output that visually implies determinate or indeterminate progress
  - command/task activity inferred from terminal text alone

Current judgment:

- The backend already has enough truth for a first richer host-semantic lane
  around activity/task state.
- The backend does not yet have a structured progress model.
- A first enriched contract should probably start with activity/task semantics
  before attempting determinate progress values.

Likely first candidate packet:

- task/activity state
  - running / idle / exited
  - foreground-process-present
  - foreground-process-label if available
  - semantic-command-active
  - semantic prompt exit code when known

Explicitly deferred until a real backend source of truth exists:

- percentage progress
- progress text labels
- host badge/chip styling
- notification/toast decisions

## Classification Notes

`FHS-02` initial classification, 2026-03-17:

- Backend facts
  - title
  - cwd
  - scrollback count / offset
  - alt-screen state
  - mouse-reporting state
  - alive / child exit status
  - semantic prompt state
  - foreground-process-present
  - foreground-process-label when transport can determine it
- Bridge conveniences over backend facts
  - close-confirm signals
    - useful host summary, but derived from lower-level backend facts
  - title substitution with foreground-process label
    - convenient for hosts, but presentation-biased and not raw engine truth
- Host policy or presentation
  - tab-chip text
  - badge colors / icons / spinners
  - notification / toast decisions
  - whether to show progress in tabs, window chrome, dock/taskbar, or overlays
- Not yet structured enough for exposure
  - inferred build progress from terminal text patterns
  - inferred task labels from redrawing status lines

Current rule from this pass:

- promote backend facts
- be cautious with bridge conveniences
- keep host policy out of the shared contract

## Reference Notes

`FHS-04` initial reference check, 2026-03-17:

- Ghostty
  - exposes progress as an explicit terminal-to-surface message path
  - see `src/terminal/stream.zig` and `src/termio/stream_handler.zig`
  - host UI then renders it in the GTK surface layer
  - this supports the "structured semantic fact, host-owned presentation"
    model
- Kitty
  - has explicit progress parsing/state and host-side tab/taskbar integration
  - see `kitty/progress.py`, `kitty/tab_bar.py`, and `kitty/boss.py`
  - also tracks activity/bell state separately from title text
  - this supports exposing progress/activity as state, not as UI instructions
- Zide today
  - has structured activity-adjacent facts
  - does not yet have structured progress state
  - therefore activity/task semantics should come first
- Windows Terminal
  - official source is open at `microsoft/terminal`
  - official docs also describe explicit OSC `9;4` progress support
  - that means all three references in this lane now point the same way:
    structured progress/activity state is a real terminal/host integration
    family, not just a Zide-specific UI idea
  - local checkout is still missing under `reference_repos`, so code-level
    comparison should still be added before implementation work that depends on
    Windows-specific details

## Done When

- Zide has an explicit list of host-visible semantics worth exposing beyond the
  current metadata/events surface.
- Each exposed semantic is justified as shared backend truth, not native-only UI
  convenience.
- The bridge can support richer host UX, including progress-oriented tab state,
  without becoming a presentation API.

## First Packet Proposal

`FHS-03` draft, 2026-03-17:

Proposed first enriched host-semantic packet:

- `ActivityMetadata`
  - `abi_version`
  - `struct_size`
  - `running`
  - `has_exit_code`
  - `exit_code`
  - `foreground_process_present`
  - `foreground_process_label_ptr`
  - `foreground_process_label_len`
  - `semantic_prompt_active`
  - `semantic_input_active`
  - `semantic_output_active`
  - `semantic_prompt_kind`
  - `semantic_prompt_exit_code_known`
  - `semantic_prompt_exit_code`
  - `_ctx`

Notes:

- `running` is the coarse host-facing task truth.
- `foreground_process_present` and optional label help hosts distinguish shell
  idle vs a real foreground task.
- semantic prompt fields let hosts surface command activity/completion without
  parsing terminal text.
- no title/cwd duplication in this packet unless later measurement shows that
  hosts need a co-acquired convenience form.

Deliberate omissions from the first packet:

- no progress percentage
- no progress text
- no attention/bell state yet
- no UI-facing status strings
- no host-specific presentation hints

## Transport Proposal

`FHS-05` draft, 2026-03-17:

Current preferred transport: latest-state metadata acquire, not event stream.

Why:

- activity/task state is primarily latest-state truth, similar to current
  `metadata_acquire(...)`
- hosts will often want the current answer when painting tabs or workspace
  chrome, not every transition edge
- the bridge already has a hot/cold split where redraw/snapshot is hot and
  metadata is a colder latest-state read
- event-only delivery would force hosts to cache and reconcile state just to
  answer simple UI questions

Current preferred shape:

- extend metadata with an optional include flag for activity/task semantics
  (current preferred shape)
- only add a parallel `activity_metadata_acquire(...)` if later measurement
  shows that metadata struct growth or ownership pressure is materially worse
  than one authoritative latest-state acquire

Current non-preferred shape:

- event-only activity/task changes
  - okay later as a secondary optimization
  - not okay as the only authoritative host path

Decision bias from current bridge shape:

- latest-state first
- events second, only if they materially reduce churn after the latest-state
  authority is in place
- extend the existing latest-state authority before adding a sibling acquire API

## Current API Decision

Current preferred implementation direction, 2026-03-17:

- extend `metadata_acquire(...)`
- bump metadata ABI version
- add a new metadata include flag for activity/task semantics
- keep `include_flags = 0` valid for the current hot-scalar baseline
- only populate/copy activity-task strings such as
  `foreground_process_label` when the include flag is requested

Why this is preferred:

- the bridge already treats `metadata_acquire(...)` as the authoritative
  latest-state summary
- request-based optional strings are already the chosen maturity pattern for
  title/cwd
- a sibling `activity_metadata_acquire(...)` would add another latest-state
  authority surface before the first one has actually proven insufficient
- current docs and performance review both prefer one authoritative getter over
  several convenience getters

Current rejection criteria for a separate acquire API:

- "activity feels important" is not enough
- "native already reads it internally" is not enough
- only real host-call-count, ownership, or struct-growth pressure should reopen
  that decision

## Draft ABI Sketch

Current preferred first-cut metadata extension:

```c
typedef struct ZideTerminalMetadata {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t scrollback_count;
    uint32_t scrollback_offset;
    uint8_t alive;
    uint8_t has_exit_code;
    uint8_t foreground_process_present;
    uint8_t semantic_prompt_active;
    int32_t exit_code;
    uint8_t semantic_input_active;
    uint8_t semantic_output_active;
    uint8_t semantic_prompt_kind;
    uint8_t semantic_prompt_exit_code_known;
    uint8_t semantic_prompt_exit_code;
    uint8_t _padding1[3];
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *cwd_ptr;
    size_t cwd_len;
    const uint8_t *foreground_process_label_ptr;
    size_t foreground_process_label_len;
    void *_ctx;
} ZideTerminalMetadataV3;
```

Proposed new metadata include flag:

```c
enum {
    ZIDE_TERMINAL_METADATA_INCLUDE_TITLE = 1u << 0,
    ZIDE_TERMINAL_METADATA_INCLUDE_CWD = 1u << 1,
    ZIDE_TERMINAL_METADATA_INCLUDE_ACTIVITY = 1u << 2,
};
```

Expected semantics:

- `alive`, `has_exit_code`, and `exit_code` keep their current meaning.
- `foreground_process_present` is a cheap scalar latest-state fact.
- `semantic_prompt_*` fields are always scalar state, not copied strings.
- `foreground_process_label_ptr/len` are only populated when
  `INCLUDE_ACTIVITY` is requested.
- omitted optional strings come back as `ptr = null`, `len = 0`.
- release remains unconditional and identical to current metadata release.

Current flattening choice:

- keep semantic prompt fields flattened in the C ABI
- avoid nested structs for the first cut

Why flattened is preferred:

- matches the existing flat metadata style
- easier for C, Python, Dart, and Swift bindings
- avoids a second ABI-shape discussion before the semantics are proven

Current caveat:

- if metadata growth becomes excessive, split by authority boundary, not by UI
  feature wish list
- do not create a separate "progress metadata" or "tab metadata" family
