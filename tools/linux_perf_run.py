#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


TOOL_VERSION = "0.1"
DEFAULT_RUNS_DIR = Path("perf_runs")
PERF_PRESETS: Dict[str, List[str]] = {
    "core": [
        "terminal.frame",
        "input.latency",
        "terminal.wake",
        "editor.perf",
    ],
    "terminal": [
        "terminal.frame",
        "input.latency",
        "terminal.wake",
    ],
    "editor": [
        "editor.perf",
        "input.latency",
    ],
}
DEFAULT_PERF_PRESET = "core"


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    launch_cmd: Optional[List[str]] = None
    if "--launch" in raw_argv:
        idx = raw_argv.index("--launch")
        launch_cmd = raw_argv[idx + 1 :]
        raw_argv = raw_argv[:idx]
        if launch_cmd and launch_cmd[0] == "--":
            launch_cmd = launch_cmd[1:]

    parser = argparse.ArgumentParser(
        description="Create a packaged Linux performance run folder for one workload.",
        epilog="Use either --pid PID or --launch -- <command...>.",
    )
    parser.add_argument("--pid", type=int, help="Existing PID to monitor.")
    parser.add_argument("--label", required=True, help="Stable run label, for example terminal_btop_idle.")
    parser.add_argument("--runs-dir", type=Path, default=DEFAULT_RUNS_DIR, help="Base directory for perf run folders.")
    parser.add_argument("--interval-ms", type=int, default=250, help="Sampling interval in milliseconds.")
    parser.add_argument("--duration-s", type=float, default=None, help="Optional max duration in seconds.")
    parser.add_argument("--no-gpu", action="store_true", help="Disable optional NVIDIA pmon sampling.")
    parser.add_argument(
        "--subsystem-events",
        action="append",
        type=Path,
        default=[],
        help="Optional structured subsystem event JSONL file to package; repeat as needed.",
    )
    parser.add_argument(
        "--note",
        action="append",
        default=[],
        help="Optional note line to write into notes.txt; repeat as needed.",
    )
    parser.add_argument(
        "--tag",
        action="append",
        default=[],
        help="Optional run tag to attach in manifest metadata; repeat as needed.",
    )
    parser.add_argument(
        "--keep-host-csv",
        action="store_true",
        help="Also persist host_resources.csv in the run folder.",
    )
    parser.add_argument(
        "--capture-zide-perf",
        action="store_true",
        help="Temporarily configure .zide.lua to write grouped perf JSONL events into this run folder.",
    )
    parser.add_argument(
        "--zide-project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root containing .zide.lua for temporary perf capture setup.",
    )
    parser.add_argument(
        "--perf-tag",
        action="append",
        default=[],
        help="Extra perf tag to capture when --capture-zide-perf is enabled; repeat as needed.",
    )
    parser.add_argument(
        "--perf-preset",
        choices=sorted(PERF_PRESETS.keys()),
        default=DEFAULT_PERF_PRESET,
        help="Named perf logging preset to use for --capture-zide-perf.",
    )
    args = parser.parse_args(raw_argv)
    args.launch = launch_cmd
    if args.pid is None and args.launch is None:
        parser.error("one of --pid or --launch is required")
    if args.pid is not None and args.launch is not None:
        parser.error("--pid and --launch are mutually exclusive")
    if args.launch is not None and not args.launch:
        parser.error("--launch requires a command")
    if args.capture_zide_perf and args.pid is not None:
        parser.error("--capture-zide-perf currently requires --launch")
    return args


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def sanitize_label(label: str) -> str:
    keep = []
    for ch in label:
        if ch.isalnum() or ch in {"-", "_", "."}:
            keep.append(ch)
        else:
            keep.append("_")
    return "".join(keep).strip("_") or "run"


def make_run_dir(base_dir: Path, label: str) -> Path:
    run_dir = base_dir / f"{utc_stamp()}_{sanitize_label(label)}"
    run_dir.mkdir(parents=True, exist_ok=False)
    return run_dir


def host_info() -> Dict[str, Any]:
    return {
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "python": platform.python_version(),
    }


def read_jsonl(path: Path) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    if not path.exists():
        return items
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            items.append(json.loads(line))
    return items


def summarize_host_samples(samples: List[Dict[str, Any]]) -> Dict[str, Any]:
    def numeric_summary(key: str) -> Dict[str, Optional[float]]:
        values = [sample[key] for sample in samples if sample.get(key) is not None]
        if not values:
            return {"avg": None, "peak": None}
        return {
            "avg": float(sum(values)) / len(values),
            "peak": float(max(values)),
        }

    last = samples[-1] if samples else {}
    return {
        "sample_count": len(samples),
        "pid": last.get("pid"),
        "elapsed_s": last.get("elapsed_s"),
        "cpu_pct": numeric_summary("cpu_pct"),
        "rss_kib": numeric_summary("rss_kib"),
        "vmsize_kib": numeric_summary("vmsize_kib"),
        "thread_count": numeric_summary("thread_count"),
        "fd_count": numeric_summary("fd_count"),
        "gpu_sm_pct": numeric_summary("gpu_sm_pct"),
        "gpu_mem_pct": numeric_summary("gpu_mem_pct"),
        "gpu_fb_mb": numeric_summary("gpu_fb_mb"),
    }


def merge_subsystem_events(paths: List[Path], output_path: Path) -> int:
    count = 0
    with output_path.open("w", encoding="utf-8") as out:
        for path in paths:
            with path.open("r", encoding="utf-8") as src:
                for line in src:
                    if not line.strip():
                        continue
                    out.write(line if line.endswith("\n") else line + "\n")
                    count += 1
    return count


def write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_notes(path: Path, notes: List[str]) -> None:
    if not notes:
        return
    path.write_text("".join(f"{note}\n" for note in notes), encoding="utf-8")


def monitor_command(args: argparse.Namespace, host_jsonl: Path, host_csv: Optional[Path]) -> List[str]:
    cmd = [
        sys.executable,
        "tools/linux_resource_monitor.py",
        "--interval-ms",
        str(args.interval_ms),
        "--jsonl",
        str(host_jsonl),
    ]
    if host_csv is not None:
        cmd.extend(["--csv", str(host_csv)])
    if args.duration_s is not None:
        cmd.extend(["--duration-s", str(args.duration_s)])
    if args.no_gpu:
        cmd.append("--no-gpu")
    if args.pid is not None:
        cmd.extend(["--pid", str(args.pid)])
    else:
        cmd.extend(["--launch", "--", *args.launch])
    return cmd


def lua_quote(value: str) -> str:
    return json.dumps(value)


def resolved_perf_tags(args: argparse.Namespace) -> List[str]:
    tags: List[str] = []
    seen = set()
    for tag in PERF_PRESETS[args.perf_preset]:
        if tag not in seen:
            tags.append(tag)
            seen.add(tag)
    for tag in args.perf_tag:
        if tag not in seen:
            tags.append(tag)
            seen.add(tag)
    return tags


def count_jsonl_records(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("r", encoding="utf-8") as f:
        return sum(1 for line in f if line.strip())


@contextlib.contextmanager
def temporary_zide_perf_override(project_root: Path, subsystem_jsonl: Path, tags: List[str]):
    project_root = project_root.resolve()
    project_config = project_root / ".zide.lua"
    backup_path = project_root / ".zide.lua.codex-perf-backup"
    original_exists = project_config.exists()
    original_text = project_config.read_text(encoding="utf-8") if original_exists else None

    if backup_path.exists():
        raise RuntimeError(f"perf backup path already exists: {backup_path}")

    try:
        if original_text is not None:
            backup_path.write_text(original_text, encoding="utf-8")
        tags_lua = ", ".join(lua_quote(tag) for tag in tags)
        override = f"""local base = {{}}
local ok, loaded = pcall(dofile, {lua_quote(backup_path.name)})
if ok and type(loaded) == "table" then
  base = loaded
end
base.logs = base.logs or {{}}
base.logs.groups = base.logs.groups or {{}}
base.logs.groups.perf = {{
  file = {lua_quote(str(subsystem_jsonl.resolve()))},
  mode = "jsonl",
  tags = {{ {tags_lua} }},
}}
return base
"""
        project_config.write_text(override, encoding="utf-8")
        yield
    finally:
        if original_text is not None:
            project_config.write_text(original_text, encoding="utf-8")
        else:
            try:
                project_config.unlink()
            except FileNotFoundError:
                pass
        try:
            backup_path.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    args = parse_args()
    run_dir = make_run_dir(args.runs_dir, args.label)
    host_jsonl = run_dir / "host_resources.jsonl"
    host_csv = run_dir / "host_resources.csv" if args.keep_host_csv else None
    subsystem_jsonl = run_dir / "subsystem_events.jsonl"
    manifest_path = run_dir / "manifest.json"
    summary_path = run_dir / "summary.json"
    notes_path = run_dir / "notes.txt"

    monitor_cmd = monitor_command(args, host_jsonl, host_csv)
    auto_perf_tags = resolved_perf_tags(args) if args.capture_zide_perf else []
    try:
        if args.capture_zide_perf:
            with temporary_zide_perf_override(args.zide_project_root, subsystem_jsonl, auto_perf_tags):
                monitor = subprocess.run(monitor_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        else:
            monitor = subprocess.run(monitor_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    except RuntimeError as err:
        print(str(err), file=sys.stderr)
        return 2
    if monitor.returncode != 0:
        sys.stderr.write(monitor.stderr)
        if monitor.stdout:
            sys.stderr.write(monitor.stdout)
        return monitor.returncode

    samples = read_jsonl(host_jsonl)
    if not samples:
        print(f"run folder created at {run_dir}, but no host samples were captured", file=sys.stderr)
        return 1

    subsystem_paths = [path for path in args.subsystem_events if path.exists()]
    subsystem_event_count = 0
    if args.capture_zide_perf:
        subsystem_event_count = count_jsonl_records(subsystem_jsonl)
    elif subsystem_paths:
        subsystem_event_count = merge_subsystem_events(subsystem_paths, subsystem_jsonl)

    manifest = {
        "tool": {
            "name": "linux_perf_run",
            "version": TOOL_VERSION,
        },
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "label": args.label,
        "tags": args.tag,
        "host": host_info(),
        "monitor": {
            "interval_ms": args.interval_ms,
            "duration_s": args.duration_s,
            "gpu_sampling": not args.no_gpu,
        },
        "workload": {
            "pid": args.pid,
            "launch": args.launch,
        },
        "zide_perf_capture": {
            "enabled": args.capture_zide_perf,
            "project_root": str(args.zide_project_root.resolve()) if args.capture_zide_perf else None,
            "preset": args.perf_preset if args.capture_zide_perf else None,
            "tags": auto_perf_tags,
        },
        "artifacts": {
            "host_resources_jsonl": host_jsonl.name,
            "host_resources_csv": host_csv.name if host_csv is not None else None,
            "subsystem_events_jsonl": subsystem_jsonl.name if subsystem_event_count > 0 else None,
            "notes": notes_path.name if args.note else None,
        },
        "subsystem_event_sources": [str(path) for path in subsystem_paths],
        "monitor_stdout": monitor.stdout.strip().splitlines(),
    }
    write_json(manifest_path, manifest)

    summary = {
        "host_resources": summarize_host_samples(samples),
        "subsystem_event_count": subsystem_event_count,
        "run_dir": str(run_dir),
    }
    write_json(summary_path, summary)
    write_notes(notes_path, args.note)

    print(f"run_dir={run_dir}")
    print(f"manifest={manifest_path}")
    print(f"summary={summary_path}")
    print(f"host_resources_jsonl={host_jsonl}")
    if host_csv is not None:
        print(f"host_resources_csv={host_csv}")
    if subsystem_event_count > 0:
        print(f"subsystem_events_jsonl={subsystem_jsonl}")
        print(f"subsystem_event_count={subsystem_event_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
