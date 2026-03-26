# Structured Logging

Date: 2026-03-26

Purpose: define how Zide logging should evolve from human-oriented tag lines
into a structured seam that supports:

- ordinary grep/debug workflows
- performance capture tooling
- future internal visual inspection tools

This is the authority for:

- logger output-mode direction
- machine-readable event-line requirements
- grouped log-file routing direction
- the relationship between logging and performance tooling

It is not the authority for:

- runtime budgets and lifecycle policy
- subsystem-specific event vocabularies
- config merge rules

Those remain owned by:

- `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md`
- subsystem architecture docs
- `app_architecture/CONFIG.md`

## Why This Exists

Current logger strengths:

- cheap tag-based routing
- console vs file filters
- per-tag level overrides
- good human-readable debugging

Current gap:

- logs are not yet a stable machine seam
- performance tooling cannot safely depend on ad hoc message strings forever
- future visual tooling needs structured events, not regex over prose

## Core Rule

Zide should keep one logging system, not separate:

- human logs
- machine logs
- viewer-only telemetry

Instead:

- one logger
- one event model
- multiple output formats and sinks

## Output Modes

The logger should support at least two output modes:

### 1. Text mode

For:

- ordinary debugging
- terminal grep
- low-friction issue investigation

Keep the current human-readable shape or a close variant.

### 2. Structured mode

For:

- performance capture tooling
- machine parsing
- stable event ingestion
- future internal viewer input

Preferred shape:

- JSONL

Reason:

- append-friendly
- line-oriented
- grep-compatible enough
- easy in Python and TypeScript
- easy to package into run artifacts

## Structured Event Requirements

Every machine-readable event should carry:

- timestamp
- monotonic elapsed time
- level
- tag
- message
- optional structured fields map

Recommended minimum JSONL shape:

```json
{
  "ts_wall": "2026-03-26T10:15:00.123456Z",
  "ts_us": 123456,
  "level": "info",
  "tag": "terminal.wake",
  "msg": "workspace poll",
  "fields": {
    "active_lifecycle": "focused_visible",
    "background_lifecycle": "hidden_warm",
    "active_polled": 2
  }
}
```

Important rule:

- structured logs should not require reparsing `msg`
- values that matter to tools should be explicit fields

## Event Vocabulary Direction

Structured logging should align with runtime/resource vocabulary:

- runtime kind
- lifecycle tier
- work class
- budget
- backlog / spillover / cooling hints

This does not mean every log line needs all fields.

It means:

- when a subsystem emits machine-relevant events, it should use stable shared
  vocabulary where that vocabulary already exists

## Sink Routing

The logger should support grouped file routing in addition to the main log.

Examples:

- `perf`
  - `terminal.frame`
  - `terminal.wake`
  - `editor.perf`
  - `input.latency`
- `terminal`
  - `terminal.*`
- `editor`
  - `editor.*`

This routing should be:

- opt-in
- config-driven
- tag-pattern based

Important rule:

- grouped sink files are additional views of the same event stream
- they must not invent a second event contract

## Config Direction

Lua config should remain the operator-facing control surface.

Expected future config growth:

- log output mode:
  - `text`
  - `jsonl`
- optional grouped file sinks:
  - group name
  - tag filters
  - file path or file-name convention

Example direction only:

```lua
return {
  logs = {
    mode = "jsonl",
    file = "all",
    groups = {
      perf = {
        file = "zide-perf.jsonl",
        tags = { "terminal.frame", "terminal.wake", "editor.perf", "input.latency" },
      },
      terminal = {
        file = "zide-terminal.jsonl",
        tags = { "terminal.*" },
      },
    },
  },
}
```

Exact config syntax can change, but the model should stay:

- one logger
- one event model
- configurable views/sinks

## Relationship To Performance Tooling

This doc and `app_architecture/tools/PERFORMANCE_TOOLING.md` must stay aligned.

Split:

- this doc defines logging as a structured event seam
- performance tooling defines capture packaging, summaries, and viewer
  consumption

Practical rule:

- performance tooling should prefer structured event artifacts over parsing
  free-form text logs whenever possible

## Non-Goals

- no full tracing framework
- no mandatory always-on heavy structured logging
- no separate metrics database
- no viewer-only event path
- no replacing counters with logs where counters are the better primitive

## Expected Implementation Order

1. add logger output modes
2. add structured event-line support
3. add grouped file sinks
4. migrate performance-relevant tags to stable structured fields
5. teach the perf CLI to ingest structured event files directly

## Current Constraint

Until structured mode exists:

- current text logs remain useful for humans
- performance tooling should treat them as transitional input, not a permanent
  machine contract

## Current Implementation Checkpoint

2026-03-26:

- logger output modes are now implemented in `src/app_logger.zig`
- supported sink modes are:
  - `text`
  - `jsonl`
- Lua config now supports:
  - `logs.mode`
  - `logs.file_mode`
  - `logs.console_mode`
  - direct `log_file_output_mode`
  - direct `log_console_output_mode`
- grouped file sinks are now implemented through:
  - `logs.groups.<name>.tags`
  - `logs.groups.<name>.file`
  - `logs.groups.<name>.mode`
- grouped tag filters support:
  - exact tag matches
  - `prefix.*` wildcard prefixes
- direct per-sink keys override shared `logs.mode`

Current limitation:

- structured output currently stabilizes the envelope only:
  - `ts_wall`
  - `ts_us`
  - `level`
  - `tag`
  - `msg`

2026-03-26 follow-up:

- structured `fields` support is now implemented in `src/app_logger.zig`
- first migrated machine-relevant tags are:
  - `terminal.frame`
  - `input.latency`
  - `terminal.wake`
  - `editor.perf`

Current limitation:

- only the first high-value perf/runtime tags have stable explicit fields so far
- broader subsystem migration is still needed before the text `msg` can be
  treated as purely human-oriented everywhere
