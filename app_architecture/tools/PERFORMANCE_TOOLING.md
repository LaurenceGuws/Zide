# Performance Tooling

Date: 2026-03-26

Purpose: define the first-class performance and resource-measurement tooling
model for Zide.

This is the authority for:

- performance CLI ownership
- capture artifact shape
- host-resource vs subsystem-attribution boundaries
- future internal performance viewer split

It is not the authority for:

- terminal scheduler policy
- editor runtime architecture
- renderer scene ownership

Those remain owned by their subsystem docs.

## Product Goal

Performance tooling should be:

- first-class for both agents and users
- CLI-first and scriptable
- easy to compare across runs
- able to correlate host resource usage with Zide subsystem counters
- later viewable through a local internal graphical tool

Important rule:

- the CLI is the source of truth
- the graphical tool is a client of the same capture artifacts

The viewer must not become a second telemetry system.

## Tooling Split

### 1. Capture CLI

Canonical responsibility:

- launch workloads
- sample host resources
- ingest or align Zide-owned subsystem counters/logs
- emit stable capture artifacts
- print concise summaries for terminal use

This surface must remain usable without any browser or GUI.

### 2. Artifact layer

Canonical responsibility:

- stable run manifest
- time-series sample data
- subsystem summaries / derived metrics
- comparable run metadata

This is the contract between CLI and viewer.

### 3. Local performance viewer

Canonical responsibility:

- open existing capture artifacts
- compare runs visually
- drill down by process, subsystem, and time window
- remain local and operator-focused

The viewer should not own sampling logic.

## Recommended Implementation Stack

### Capture / orchestration

Preferred near-term stack:

- Python

Why:

- best local ergonomics for process launching, `/proc` sampling, JSON/CSV
  handling, and optional host-tool integration
- already used in repo tooling
- fast to iterate for operator workflows
- good enough unless capture hot-path cost itself becomes a bottleneck

Use Python for:

- workload runner
- resource sampler
- log alignment helpers
- capture packaging

### Viewer

Preferred stack:

- TypeScript local web app

Why:

- strongest UX for dense interactive visual exploration
- easiest path for time-series charts, filtering, diffing, and drill-down
- can stay local and static or near-static

Recommended split:

- browser UI in TypeScript
- no heavy long-running backend by default
- open capture artifacts from a small local HTTP host or file-serving helper

### Do not start with

- Electron
- a database-backed local daemon
- a Python server that also owns the actual viewer state model
- a second bespoke capture format only for the UI

Those all raise complexity too early.

## Recommendation

Best UX/DX path for Zide:

1. Python CLI remains canonical
2. capture artifacts are stable JSON-first files
3. local viewer is a TypeScript web app that reads those artifacts
4. only add a tiny Python HTTP host if browser loading needs it

So:

- Python is the right tool for capture
- TypeScript is the right tool for visuals
- but the data contract is the real product seam

## Capture Artifact Model

Each run should live in one folder, for example:

```text
perf_runs/
  2026-03-26T10-15-00Z_terminal_btop_idle/
    manifest.json
    host_resources.jsonl
    subsystem_events.jsonl
    summary.json
    notes.txt
```

Required files:

- `manifest.json`
  - tool version
  - host info
  - command
  - sampling interval
  - run labels / tags
  - workload metadata
- `host_resources.jsonl`
  - process and optional GPU samples
- `summary.json`
  - aggregated metrics and peaks

Optional files:

- `subsystem_events.jsonl`
  - normalized Zide subsystem counters or aligned log-derived events
- `notes.txt`
  - manual context

## Data Model Direction

### Host-resource samples

Examples:

- timestamp
- pid
- process name / command
- CPU percent
- RSS / VMS
- thread count
- fd count
- IO bytes
- context switches
- optional GPU fields

### Subsystem events / counters

Examples:

- terminal workspace poll counters
- editor search/highlight runtime counters
- frame pacing / redraw counters
- future renderer counters

### Derived summaries

Examples:

- average / peak CPU
- average / peak RSS
- peak GPU FB memory
- budget spillover rate
- search sync-fallback rate
- highlight init failure count

## Comparison Workflow

The tooling should optimize for repeatable comparisons:

- Zide idle vs Kitty idle
- Zide `btop` vs Kitty `btop`
- Zide one busy tab vs many busy tabs
- current `main` vs previous checkpoint

That means the CLI needs:

- labels
- comparable workload names
- deterministic output folder names
- summary diff support later

## Viewer Requirements

The future viewer should support:

- run list
- overlay compare of multiple runs
- synchronized time cursor
- per-process tracks
- subsystem tracks
- summary cards
- export of selected windows

The viewer should feel like an internal operator instrument, not a dashboard toy.

## Near-Term Execution Order

1. strengthen the Python CLI into a capture runner, not just a sampler
2. define the stable run-folder artifact contract
3. normalize current subsystem counters into machine-readable event output
4. only then build the local TypeScript viewer on top of those artifacts

## Non-Goals

- no remote telemetry service
- no mandatory background daemon
- no CI performance pipeline
- no proprietary binary capture format
- no viewer-only metrics path

## Current Starting Point

Existing surfaces already in repo:

- `tools/linux_resource_monitor.py`
- terminal poll runtime counters
- editor search/highlight runtime counters
- existing perf and latency logs

Those should now converge into one first-class performance tooling lane rather
than staying as isolated scripts and logs.
