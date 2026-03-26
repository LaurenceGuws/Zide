# Linux Resource Profiling

Purpose: define the supported local workflow for measuring Zide resource usage
on Linux under real workloads.

This is operator guidance, not architecture authority.

Use this when you want:

- process CPU and memory truth under load
- thread/fd/context-switch growth over time
- optional per-process NVIDIA graphics memory and utilization samples
- correlation with Zide subsystem counters already emitted by app logs
- packaged perf run folders that keep host samples and subsystem events together

## What Is Trustworthy

There are two different measurement classes:

1. Host process resource usage
   - authoritative source: Linux `/proc`
   - examples:
     - CPU percent
     - RSS / virtual memory
     - thread count
     - file-descriptor count
     - read/write bytes
     - voluntary / nonvoluntary context switches

2. Zide subsystem activity
   - authoritative source: Zide-owned counters and logs
   - examples:
     - terminal workspace poll counters
     - editor search/highlight runtime counters
     - frame pacing / input-latency logs

Important rule:

- do not pretend we have direct per-subsystem CPU percentages unless we really
  implement a sampler for that
- today, subsystem attribution is correlation-based:
  host resource samples + Zide subsystem counters over the same workload window

## Current Tool

Use:

- `tools/perf/linux_resource_monitor.py`
- `tools/perf/linux_perf_run.py`

It supports:

- monitoring an existing PID
- launching a command and monitoring the resulting process
- JSONL and CSV output
- optional NVIDIA per-process graphics sampling via `nvidia-smi pmon`
- packaged run folders with:
  - `manifest.json`
  - `host_resources.jsonl`
  - `summary.json`
  - optional `subsystem_events.jsonl`
  - optional `notes.txt`

## Basic Usage

Create a packaged perf run folder:

```bash
python3 tools/perf/linux_perf_run.py \
  --label terminal_sleep_smoke \
  --interval-ms 100 \
  --launch -- /bin/sh -lc 'sleep 0.2'
```

Package existing structured subsystem events alongside host samples:

```bash
python3 tools/perf/linux_perf_run.py \
  --label zide_terminal_btop \
  --interval-ms 250 \
  --subsystem-events ~/.cache/zide-perf.jsonl \
  --launch -- ./zig-out/bin/zide-terminal --shell /bin/zsh --command btop
```

Let the runner temporarily wire Zide perf sinks itself:

```bash
python3 tools/perf/linux_perf_run.py \
  --label zide_terminal_btop \
  --capture-zide-perf \
  --perf-preset terminal \
  --launch -- ./zig-out/bin/zide-terminal --shell /bin/zsh --command btop
```

Notes:

- `--capture-zide-perf` is launch-only right now
- it temporarily rewrites `./.zide.lua` in the chosen project root
- it restores the prior `./.zide.lua` contents on exit
- preset-driven capture is preferred over ad hoc tag lists
- current presets:
  - `core`
    - `terminal.frame`
    - `input.latency`
    - `terminal.wake`
    - `editor.perf`
  - `terminal`
    - `terminal.frame`
    - `input.latency`
    - `terminal.wake`
  - `editor`
    - `editor.perf`
    - `input.latency`
- `--perf-tag` can still add extra tags on top of a preset

Monitor an existing Zide PID:

```bash
python3 tools/perf/linux_resource_monitor.py \
  --pid 43279 \
  --interval-ms 250 \
  --jsonl ~/.cache/zide-agent-scratch/zide-terminal.jsonl \
  --csv ~/.cache/zide-agent-scratch/zide-terminal.csv
```

Launch and monitor a fresh terminal instance:

```bash
python3 tools/perf/linux_resource_monitor.py \
  --interval-ms 250 \
  --jsonl ~/.cache/zide-agent-scratch/zide-terminal.jsonl \
  --launch -- ./zig-out/bin/zide-terminal --shell /bin/zsh --command btop
```

Limit capture duration:

```bash
python3 tools/perf/linux_resource_monitor.py \
  --pid 43279 \
  --duration-s 15 \
  --interval-ms 200
```

Disable GPU sampling:

```bash
python3 tools/perf/linux_resource_monitor.py \
  --pid 43279 \
  --no-gpu
```

## Output Meaning

Per-sample fields include:

- `cpu_pct`
  - process CPU percent in top-style single-core units
  - `100` means one core fully busy
- `rss_kib`
  - resident memory in KiB
- `vmsize_kib`
  - virtual address space in KiB
- `thread_count`
- `fd_count`
- `read_bytes`
- `write_bytes`
- `voluntary_ctxt_switches`
- `nonvoluntary_ctxt_switches`
- optional NVIDIA fields:
  - `gpu_sm_pct`
  - `gpu_mem_pct`
  - `gpu_fb_mb`

Summary output prints averages and peaks over the capture window.

## Correlating With Zide Subsystems

Use the resource monitor together with focused Zide log tags.

Current useful subsystem signals:

- terminal:
  - `input_latency`
  - `terminal.frame`
  - `terminal.wake`
- editor:
  - `editor.perf`
  - `editor.search`
  - `editor.highlight`

Current in-app counter surfaces:

- terminal workspace poll counters:
  - active/background poll totals
  - budget totals
  - backlog/spillover hint totals
- editor search/highlight counters:
  - async schedules
  - sync fallbacks
  - stale-result drops
  - worker spawn failures
  - highlight scheduling / skip / init totals

Practical workflow:

1. choose one repeatable workload
2. capture resource samples with `linux_resource_monitor.py`
   - or package one full run with `linux_perf_run.py`
3. capture only the minimal Zide log tags for the suspected subsystem
4. compare:
   - idle window
   - steady-state workload window
   - post-focus-switch window if relevant

## GPU Scope Notes

GPU sampling is intentionally conservative:

- current tool uses `nvidia-smi pmon` only when available
- this is Linux/NVIDIA-specific
- on other GPU stacks, host GPU sampling is currently unsupported by this tool

What is still useful even without GPU sampling:

- CPU / RSS / threads / fd growth
- Zide frame and subsystem counters

## Recommended Baselines

For terminal:

- idle terminal window
- idle terminal with `btop`
- active `btop`
- multiple busy terminal tabs

For editor:

- idle large buffer
- search over large buffer
- highlight warmup / scroll pass

For comparisons against other terminals/editors:

- use the same workload command
- use the same sampling interval and duration
- compare peak CPU, average CPU, peak RSS, and if available GPU FB memory
