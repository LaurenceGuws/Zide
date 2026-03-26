#!/usr/bin/env python3
import argparse
import csv
import json
import math
import os
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, List, Optional


CLK_TCK = os.sysconf(os.sysconf_names["SC_CLK_TCK"])


@dataclass
class Sample:
    timestamp_s: float
    elapsed_s: float
    pid: int
    cpu_pct: Optional[float]
    rss_kib: Optional[int]
    vmsize_kib: Optional[int]
    thread_count: Optional[int]
    fd_count: Optional[int]
    read_bytes: Optional[int]
    write_bytes: Optional[int]
    voluntary_ctxt_switches: Optional[int]
    nonvoluntary_ctxt_switches: Optional[int]
    gpu_index: Optional[int]
    gpu_type: Optional[str]
    gpu_sm_pct: Optional[float]
    gpu_mem_pct: Optional[float]
    gpu_fb_mb: Optional[int]
    gpu_ccpm_mb: Optional[int]
    command: Optional[str]


def proc_path(pid: int, name: str) -> Path:
    return Path("/proc") / str(pid) / name


def read_text(path: Path) -> Optional[str]:
    try:
        return path.read_text()
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return None


def read_cmdline(pid: int) -> Optional[str]:
    try:
        raw = proc_path(pid, "cmdline").read_bytes()
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return None
    if not raw:
        return None
    return " ".join(part.decode("utf-8", errors="replace") for part in raw.split(b"\0") if part)


def read_proc_stat(pid: int) -> Optional[Dict[str, int]]:
    text = read_text(proc_path(pid, "stat"))
    if text is None:
        return None
    close = text.rfind(")")
    if close == -1:
        return None
    fields = text[close + 2 :].split()
    if len(fields) < 22:
        return None
    return {
        "utime_ticks": int(fields[11]),
        "stime_ticks": int(fields[12]),
    }


def read_proc_status(pid: int) -> Dict[str, int]:
    text = read_text(proc_path(pid, "status"))
    out: Dict[str, int] = {}
    if text is None:
        return out
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if key in {
            "VmRSS",
            "VmSize",
            "Threads",
            "voluntary_ctxt_switches",
            "nonvoluntary_ctxt_switches",
        }:
            first = value.split()[0]
            try:
                out[key] = int(first)
            except ValueError:
                continue
    return out


def read_proc_io(pid: int) -> Dict[str, int]:
    text = read_text(proc_path(pid, "io"))
    out: Dict[str, int] = {}
    if text is None:
        return out
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {"read_bytes", "write_bytes"}:
            try:
                out[key] = int(value)
            except ValueError:
                continue
    return out


def read_fd_count(pid: int) -> Optional[int]:
    try:
        return len(os.listdir(proc_path(pid, "fd")))
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return None


def nvidia_pmon_available() -> bool:
    return shutil.which("nvidia-smi") is not None


def parse_pmon_value(raw: str) -> Optional[float]:
    raw = raw.strip()
    if raw in {"-", "N/A"}:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def parse_pmon_int(raw: str) -> Optional[int]:
    raw = raw.strip()
    if raw in {"-", "N/A"}:
        return None
    try:
        return int(raw)
    except ValueError:
        return None


def sample_nvidia_pmon() -> Dict[int, Dict[str, object]]:
    if not nvidia_pmon_available():
        return {}
    try:
        result = subprocess.run(
            ["nvidia-smi", "pmon", "-c", "1", "-s", "um"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
    except OSError:
        return {}
    if result.returncode != 0:
        return {}
    out: Dict[int, Dict[str, object]] = {}
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 11:
            continue
        pid = parse_pmon_int(parts[1])
        if pid is None:
            continue
        out[pid] = {
            "gpu_index": parse_pmon_int(parts[0]),
            "gpu_type": parts[2],
            "gpu_sm_pct": parse_pmon_value(parts[3]),
            "gpu_mem_pct": parse_pmon_value(parts[4]),
            "gpu_fb_mb": parse_pmon_int(parts[9]),
            "gpu_ccpm_mb": parse_pmon_int(parts[10]),
            "command": parts[11] if len(parts) > 11 else None,
        }
    return out


def collect_sample(
    pid: int,
    started_at: float,
    prev_total_ticks: Optional[int],
    prev_timestamp_s: Optional[float],
    gpu_sample: Dict[int, Dict[str, object]],
) -> Optional[Sample]:
    stat = read_proc_stat(pid)
    if stat is None:
        return None
    status = read_proc_status(pid)
    io = read_proc_io(pid)
    now = time.time()
    total_ticks = stat["utime_ticks"] + stat["stime_ticks"]
    cpu_pct: Optional[float] = None
    if prev_total_ticks is not None and prev_timestamp_s is not None:
        dt = now - prev_timestamp_s
        if dt > 0:
            cpu_pct = ((total_ticks - prev_total_ticks) / CLK_TCK) / dt * 100.0

    gpu = gpu_sample.get(pid, {})
    return Sample(
        timestamp_s=now,
        elapsed_s=now - started_at,
        pid=pid,
        cpu_pct=cpu_pct,
        rss_kib=status.get("VmRSS"),
        vmsize_kib=status.get("VmSize"),
        thread_count=status.get("Threads"),
        fd_count=read_fd_count(pid),
        read_bytes=io.get("read_bytes"),
        write_bytes=io.get("write_bytes"),
        voluntary_ctxt_switches=status.get("voluntary_ctxt_switches"),
        nonvoluntary_ctxt_switches=status.get("nonvoluntary_ctxt_switches"),
        gpu_index=gpu.get("gpu_index"),
        gpu_type=gpu.get("gpu_type"),
        gpu_sm_pct=gpu.get("gpu_sm_pct"),
        gpu_mem_pct=gpu.get("gpu_mem_pct"),
        gpu_fb_mb=gpu.get("gpu_fb_mb"),
        gpu_ccpm_mb=gpu.get("gpu_ccpm_mb"),
        command=read_cmdline(pid) or gpu.get("command"),
    )


def write_jsonl(samples: List[Sample], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for sample in samples:
            f.write(json.dumps(asdict(sample), sort_keys=True))
            f.write("\n")


def write_csv(samples: List[Sample], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(asdict(samples[0]).keys()))
        writer.writeheader()
        for sample in samples:
            writer.writerow(asdict(sample))


def stat_summary(values: List[Optional[float]]) -> Dict[str, Optional[float]]:
    present = [v for v in values if v is not None]
    if not present:
        return {"avg": None, "peak": None}
    return {"avg": sum(present) / len(present), "peak": max(present)}


def stat_summary_int(values: List[Optional[int]]) -> Dict[str, Optional[float]]:
    present = [v for v in values if v is not None]
    if not present:
        return {"avg": None, "peak": None}
    return {"avg": float(sum(present)) / len(present), "peak": float(max(present))}


def print_summary(samples: List[Sample], exit_code: Optional[int]) -> None:
    cpu = stat_summary([s.cpu_pct for s in samples])
    rss = stat_summary_int([s.rss_kib for s in samples])
    vmsize = stat_summary_int([s.vmsize_kib for s in samples])
    threads = stat_summary_int([s.thread_count for s in samples])
    fds = stat_summary_int([s.fd_count for s in samples])
    gpu_sm = stat_summary([s.gpu_sm_pct for s in samples])
    gpu_mem = stat_summary([s.gpu_mem_pct for s in samples])
    gpu_fb = stat_summary_int([s.gpu_fb_mb for s in samples])
    last = samples[-1]
    print("RESOURCE SUMMARY")
    print(f"  pid={last.pid}")
    print(f"  elapsed_s={last.elapsed_s:.3f}")
    if exit_code is not None:
        print(f"  exit_code={exit_code}")
    if cpu["avg"] is not None:
        print(f"  cpu_pct_avg={cpu['avg']:.2f}")
        print(f"  cpu_pct_peak={cpu['peak']:.2f}")
    if rss["avg"] is not None:
        print(f"  rss_mib_avg={rss['avg'] / 1024.0:.2f}")
        print(f"  rss_mib_peak={rss['peak'] / 1024.0:.2f}")
    if vmsize["avg"] is not None:
        print(f"  vmsize_mib_avg={vmsize['avg'] / 1024.0:.2f}")
        print(f"  vmsize_mib_peak={vmsize['peak'] / 1024.0:.2f}")
    if threads["peak"] is not None:
        print(f"  thread_count_peak={int(threads['peak'])}")
    if fds["peak"] is not None:
        print(f"  fd_count_peak={int(fds['peak'])}")
    if gpu_sm["avg"] is not None:
        print(f"  gpu_sm_pct_avg={gpu_sm['avg']:.2f}")
        print(f"  gpu_sm_pct_peak={gpu_sm['peak']:.2f}")
    if gpu_mem["avg"] is not None:
        print(f"  gpu_mem_pct_avg={gpu_mem['avg']:.2f}")
        print(f"  gpu_mem_pct_peak={gpu_mem['peak']:.2f}")
    if gpu_fb["avg"] is not None:
        print(f"  gpu_fb_mb_avg={gpu_fb['avg']:.2f}")
        print(f"  gpu_fb_mb_peak={gpu_fb['peak']:.2f}")


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
        description="Sample Linux process resource usage from /proc and optional NVIDIA pmon.",
        epilog="Use either --pid PID or --launch -- <command...>.",
    )
    parser.add_argument("--pid", type=int, help="Existing PID to monitor.")
    parser.add_argument("--interval-ms", type=int, default=250, help="Sampling interval in milliseconds.")
    parser.add_argument("--duration-s", type=float, default=None, help="Optional max duration in seconds.")
    parser.add_argument("--jsonl", type=Path, default=None, help="Optional JSONL output path.")
    parser.add_argument("--csv", type=Path, default=None, help="Optional CSV output path.")
    parser.add_argument(
        "--no-gpu",
        action="store_true",
        help="Disable optional NVIDIA pmon GPU sampling even if available.",
    )
    args = parser.parse_args(raw_argv)
    args.launch = launch_cmd
    if args.pid is None and args.launch is None:
        parser.error("one of --pid or --launch is required")
    if args.pid is not None and args.launch is not None:
        parser.error("--pid and --launch are mutually exclusive")
    return args


def main() -> int:
    args = parse_args()
    if args.launch is not None and not args.launch:
        print("--launch requires a command", file=sys.stderr)
        return 2

    launched: Optional[subprocess.Popen] = None
    if args.launch is not None:
        launched = subprocess.Popen(args.launch)
        pid = launched.pid
    else:
        pid = args.pid

    started_at = time.time()
    interval_s = max(args.interval_ms, 10) / 1000.0
    samples: List[Sample] = []
    prev_total_ticks: Optional[int] = None
    prev_timestamp_s: Optional[float] = None
    exit_code: Optional[int] = None

    while True:
        if args.duration_s is not None and (time.time() - started_at) > args.duration_s:
            break
        if launched is not None:
            exit_code = launched.poll()
        gpu_sample = {} if args.no_gpu else sample_nvidia_pmon()
        sample = collect_sample(pid, started_at, prev_total_ticks, prev_timestamp_s, gpu_sample)
        if sample is None:
            break
        samples.append(sample)
        stat = read_proc_stat(pid)
        if stat is None:
            break
        prev_total_ticks = stat["utime_ticks"] + stat["stime_ticks"]
        prev_timestamp_s = sample.timestamp_s
        if launched is not None and exit_code is not None:
            break
        time.sleep(interval_s)

    if launched is not None and exit_code is None:
        exit_code = launched.wait(timeout=1)

    if not samples:
        print(f"no samples collected for pid={pid}", file=sys.stderr)
        return 1 if exit_code in (None, 0) else exit_code

    if args.jsonl is not None:
        write_jsonl(samples, args.jsonl)
        print(f"wrote_jsonl={args.jsonl}")
    if args.csv is not None:
        write_csv(samples, args.csv)
        print(f"wrote_csv={args.csv}")
    print_summary(samples, exit_code)
    return 0 if exit_code in (None, 0) else exit_code


if __name__ == "__main__":
    raise SystemExit(main())
