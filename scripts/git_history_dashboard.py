#!/usr/bin/env python3
"""Git history dashboard: static HTML export + dynamic local web app."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import pathlib
import re
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


COMMIT_PREFIX = "@@@"
TREE_LINE_RE = re.compile(r"^\d+\s+\w+\s+[0-9a-f]+\s+(\d+)\t(.+)$")


@dataclass
class CommitStat:
    commit: str
    timestamp: dt.datetime
    author_name: str
    author_email: str
    additions: int = 0
    deletions: int = 0
    files_touched: int = 0
    file_changes: list[tuple[str, int, int]] | None = None


class GitError(RuntimeError):
    pass


def run_git(repo: pathlib.Path, args: list[str]) -> str:
    cmd = ["git", "-C", str(repo), *args]
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise GitError(proc.stderr.strip() or f"git command failed: {' '.join(cmd)}")
    return proc.stdout


def parse_author_patterns(raw: str | None) -> list[re.Pattern[str]]:
    if not raw:
        return []
    out: list[re.Pattern[str]] = []
    for token in (part.strip() for part in raw.split(",")):
        if not token:
            continue
        out.append(re.compile(token, re.IGNORECASE))
    return out


def compile_optional_regex(raw: str | None) -> re.Pattern[str] | None:
    if not raw:
        return None
    return re.compile(raw)


def author_matches(name: str, email: str, patterns: list[re.Pattern[str]]) -> bool:
    if not patterns:
        return True
    haystack = f"{name} <{email}>"
    return any(p.search(haystack) for p in patterns)


def path_allowed(path: str, include_re: re.Pattern[str] | None, exclude_re: re.Pattern[str] | None) -> bool:
    if include_re is not None and include_re.search(path) is None:
        return False
    if exclude_re is not None and exclude_re.search(path) is not None:
        return False
    return True


def collect_commit_stats(
    repo: pathlib.Path,
    since: str | None,
    author_patterns: list[re.Pattern[str]],
    include_re: re.Pattern[str] | None,
    exclude_re: re.Pattern[str] | None,
) -> list[CommitStat]:
    args = [
        "log",
        "--reverse",
        "--date=iso-strict",
        f"--pretty=format:{COMMIT_PREFIX}%H|%cI|%an|%ae",
        "--numstat",
    ]
    if since:
        args.insert(1, f"--since={since}")

    out = run_git(repo, args)
    commits: list[CommitStat] = []
    current: CommitStat | None = None

    def flush_current() -> None:
        nonlocal current
        if current is None:
            return
        if not author_matches(current.author_name, current.author_email, author_patterns):
            current = None
            return
        if current.files_touched > 0:
            commits.append(current)
        current = None

    for raw_line in out.splitlines():
        line = raw_line.strip("\n")
        if line.startswith(COMMIT_PREFIX):
            flush_current()
            payload = line[len(COMMIT_PREFIX) :]
            commit, ts, author_name, author_email = payload.split("|", 3)
            current = CommitStat(
                commit=commit,
                timestamp=dt.datetime.fromisoformat(ts),
                author_name=author_name,
                author_email=author_email,
                file_changes=[],
            )
            continue

        if not line or current is None:
            continue

        parts = line.split("\t")
        if len(parts) < 3:
            continue

        added_raw, deleted_raw, path = parts
        if not path_allowed(path, include_re, exclude_re):
            continue

        added = int(added_raw) if added_raw.isdigit() else 0
        deleted = int(deleted_raw) if deleted_raw.isdigit() else 0
        current.additions += added
        current.deletions += deleted
        current.files_touched += 1
        current.file_changes.append((path, added, deleted))

    flush_current()
    return commits


def sample_commits(commits: list[CommitStat], max_points: int) -> list[CommitStat]:
    if not commits:
        return []
    if max_points <= 1 or len(commits) <= max_points:
        return commits
    step = int(math.ceil(len(commits) / float(max_points)))
    sampled = commits[::step]
    if sampled[-1].commit != commits[-1].commit:
        sampled.append(commits[-1])
    return sampled


def snapshot_sections_and_top_files(
    repo: pathlib.Path,
    commit_hash: str,
    include_re: re.Pattern[str] | None,
    exclude_re: re.Pattern[str] | None,
    top_n: int,
) -> tuple[dict[str, dict[str, int]], list[dict[str, Any]]]:
    out = run_git(repo, ["ls-tree", "-rl", "--long", commit_hash])
    data: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0})
    file_sizes: dict[str, int] = {}

    for line in out.splitlines():
        match = TREE_LINE_RE.match(line)
        if not match:
            continue
        size_raw, path = match.groups()
        if not path_allowed(path, include_re, exclude_re):
            continue

        size = int(size_raw)
        section = path.split("/", 1)[0] if "/" in path else "(root)"
        data[section]["files"] += 1
        data[section]["bytes"] += size
        data["__TOTAL__"]["files"] += 1
        data["__TOTAL__"]["bytes"] += size
        file_sizes[path] = size

    top_files = [
        {"file": path, "bytes": size}
        for path, size in sorted(file_sizes.items(), key=lambda kv: kv[1], reverse=True)[:top_n]
    ]
    return dict(data), top_files


def aggregate_daily(commits: list[CommitStat]) -> dict[str, list[int] | list[str]]:
    by_day: dict[str, dict[str, int]] = defaultdict(lambda: {"commits": 0, "additions": 0, "deletions": 0, "files": 0})
    for c in commits:
        day = c.timestamp.date().isoformat()
        slot = by_day[day]
        slot["commits"] += 1
        slot["additions"] += c.additions
        slot["deletions"] += c.deletions
        slot["files"] += c.files_touched

    days = sorted(by_day.keys())
    return {
        "days": days,
        "commits": [by_day[d]["commits"] for d in days],
        "additions": [by_day[d]["additions"] for d in days],
        "deletions": [by_day[d]["deletions"] for d in days],
        "files": [by_day[d]["files"] for d in days],
    }


def rolling_mean(values: list[int], window: int) -> list[float]:
    if not values:
        return []
    out: list[float] = []
    running = 0.0
    for i, value in enumerate(values):
        running += float(value)
        if i >= window:
            running -= float(values[i - window])
        out.append(running / float(min(i + 1, window)))
    return out


def cumulative_sum(values: list[int]) -> list[int]:
    out: list[int] = []
    running = 0
    for value in values:
        running += value
        out.append(running)
    return out


def top_files_data(commits: list[CommitStat], top_n: int) -> dict[str, Any]:
    touches: dict[str, int] = defaultdict(int)
    churn: dict[str, int] = defaultdict(int)
    per_day_changes: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))

    for c in commits:
        day = c.timestamp.date().isoformat()
        if c.file_changes is None:
            continue
        for path, added, deleted in c.file_changes:
            touches[path] += 1
            delta = added + deleted
            churn[path] += delta
            per_day_changes[path][day] += delta

    top_by_churn = [
        name
        for name, _ in sorted(churn.items(), key=lambda kv: kv[1], reverse=True)[:top_n]
    ]
    top_by_touches = sorted(touches.items(), key=lambda kv: kv[1], reverse=True)[:top_n]

    all_days = sorted({day for file_days in per_day_changes.values() for day in file_days})
    cumulative_by_file: dict[str, list[int]] = {}
    for name in top_by_churn:
        running = 0
        series: list[int] = []
        file_map = per_day_changes.get(name, {})
        for day in all_days:
            running += file_map.get(day, 0)
            series.append(running)
        cumulative_by_file[name] = series

    return {
        "top_by_touches": [{"file": name, "count": count} for name, count in top_by_touches],
        "top_by_churn": [{"file": name, "count": churn[name]} for name in top_by_churn],
        "days": all_days,
        "cumulative_churn": cumulative_by_file,
    }


def author_stats_data(commits: list[CommitStat], top_n: int) -> dict[str, Any]:
    commits_by_author: dict[str, int] = defaultdict(int)
    additions_by_author: dict[str, int] = defaultdict(int)
    deletions_by_author: dict[str, int] = defaultdict(int)

    for c in commits:
        key = f"{c.author_name} <{c.author_email}>"
        commits_by_author[key] += 1
        additions_by_author[key] += c.additions
        deletions_by_author[key] += c.deletions

    churn_by_author = {
        name: additions_by_author[name] + deletions_by_author[name]
        for name in commits_by_author
    }
    top_commits = sorted(commits_by_author.items(), key=lambda kv: kv[1], reverse=True)[:top_n]
    top_churn = sorted(churn_by_author.items(), key=lambda kv: kv[1], reverse=True)[:top_n]

    return {
        "top_by_commits": [{"author": name, "count": count} for name, count in top_commits],
        "top_by_churn": [{"author": name, "count": count} for name, count in top_churn],
        "top_details_by_churn": [
            {
                "author": name,
                "commits": commits_by_author.get(name, 0),
                "additions": additions_by_author.get(name, 0),
                "deletions": deletions_by_author.get(name, 0),
                "churn": churn_by_author.get(name, 0),
                "net": additions_by_author.get(name, 0) - deletions_by_author.get(name, 0),
            }
            for name, _ in top_churn
        ],
    }


def commit_heatmap_data(commits: list[CommitStat]) -> dict[str, Any]:
    # Monday=0..Sunday=6 as Python weekday()
    grid = [[0 for _hour in range(24)] for _day in range(7)]
    for c in commits:
        grid[c.timestamp.weekday()][c.timestamp.hour] += 1
    return {
        "weekdays": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        "hours": list(range(24)),
        "values": grid,
    }


def build_dashboard_data(
    repo: pathlib.Path,
    commits: list[CommitStat],
    max_points: int,
    top_sections: int,
    top_files: int,
    include_re: re.Pattern[str] | None,
    exclude_re: re.Pattern[str] | None,
) -> dict[str, Any]:
    sampled = sample_commits(commits, max_points)
    snapshots: list[dict[str, Any]] = []
    large_file_snapshots: list[dict[str, Any]] = []

    for c in sampled:
        snap, top_files_at_snapshot = snapshot_sections_and_top_files(
            repo,
            c.commit,
            include_re,
            exclude_re,
            top_files,
        )
        snapshots.append({"commit": c.commit, "date": c.timestamp.date().isoformat(), "sections": snap})
        large_file_snapshots.append(
            {
                "commit": c.commit,
                "date": c.timestamp.date().isoformat(),
                "top": top_files_at_snapshot,
            }
        )

    final_snapshot = snapshots[-1]["sections"] if snapshots else {}
    ranked_sections = sorted(
        ((name, meta["bytes"]) for name, meta in final_snapshot.items() if name != "__TOTAL__"),
        key=lambda item: item[1],
        reverse=True,
    )
    section_names = [name for name, _size in ranked_sections[:top_sections]]

    timeline_dates = [entry["date"] for entry in snapshots]
    total_files = [entry["sections"].get("__TOTAL__", {}).get("files", 0) for entry in snapshots]
    total_bytes = [entry["sections"].get("__TOTAL__", {}).get("bytes", 0) for entry in snapshots]

    files_by_section: dict[str, list[int]] = {name: [] for name in section_names}
    bytes_by_section: dict[str, list[int]] = {name: [] for name in section_names}
    for entry in snapshots:
        sections = entry["sections"]
        for name in section_names:
            meta = sections.get(name, {"files": 0, "bytes": 0})
            files_by_section[name].append(meta["files"])
            bytes_by_section[name].append(meta["bytes"])

    daily = aggregate_daily(commits)
    additions = list(daily["additions"])
    deletions = list(daily["deletions"])
    churn_abs = [a + d for a, d in zip(additions, deletions)]
    commits_daily = list(daily["commits"])

    return {
        "repo": str(repo),
        "repo_name": repo.name,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "commit_count": len(commits),
        "snapshot_count": len(snapshots),
        "timeline": {
            "dates": timeline_dates,
            "total_files": total_files,
            "total_bytes": total_bytes,
            "files_by_section": files_by_section,
            "bytes_by_section": bytes_by_section,
        },
        "activity": {
            "days": list(daily["days"]),
            "commits": commits_daily,
            "additions": additions,
            "deletions": deletions,
            "files_touched": list(daily["files"]),
            "commit_rolling_30d": rolling_mean(commits_daily, 30),
            "churn_rolling_30d": rolling_mean(churn_abs, 30),
            "cumulative_commits": cumulative_sum(commits_daily),
            "cumulative_churn": cumulative_sum(churn_abs),
            "cumulative_additions": cumulative_sum(additions),
            "cumulative_deletions": cumulative_sum(deletions),
        },
        "top_files": top_files_data(commits, top_files),
        "largest_files_timeline": large_file_snapshots,
        "authors": author_stats_data(commits, top_files),
        "commit_heatmap": commit_heatmap_data(commits),
    }


def build_cross_repo_data(repos: list[dict[str, Any]]) -> dict[str, Any]:
    all_days = sorted({day for item in repos for day in item["activity"]["days"]})

    commits_by_repo: dict[str, list[int]] = {}
    churn_by_repo: dict[str, list[int]] = {}
    final_bytes_by_repo: dict[str, int] = {}
    final_files_by_repo: dict[str, int] = {}
    author_churn_global: dict[str, int] = defaultdict(int)

    for item in repos:
        name = item["repo_name"]
        day_idx = {d: i for i, d in enumerate(item["activity"]["days"])}
        commits = item["activity"]["commits"]
        additions = item["activity"]["additions"]
        deletions = item["activity"]["deletions"]

        commits_by_repo[name] = [commits[day_idx[d]] if d in day_idx else 0 for d in all_days]
        churn_by_repo[name] = [
            (additions[day_idx[d]] + deletions[day_idx[d]]) if d in day_idx else 0
            for d in all_days
        ]

        total_bytes = item["timeline"]["total_bytes"]
        total_files = item["timeline"]["total_files"]
        final_bytes_by_repo[name] = total_bytes[-1] if total_bytes else 0
        final_files_by_repo[name] = total_files[-1] if total_files else 0
        for row in item.get("authors", {}).get("top_details_by_churn", []):
            author = row.get("author", "")
            churn = int(row.get("churn", 0))
            if author:
                author_churn_global[author] += churn

    return {
        "days": all_days,
        "commits_by_repo": commits_by_repo,
        "churn_by_repo": churn_by_repo,
        "final_bytes_by_repo": final_bytes_by_repo,
        "final_files_by_repo": final_files_by_repo,
        "top_authors_by_churn": [
            {"author": name, "count": count}
            for name, count in sorted(author_churn_global.items(), key=lambda kv: kv[1], reverse=True)[:10]
        ],
    }


def analyze_repos(payload: dict[str, Any]) -> dict[str, Any]:
    repos_raw = str(payload.get("repos", "")).strip()
    if not repos_raw:
        raise ValueError("No repository paths were provided")

    # Accept comma/newline/whitespace-separated absolute paths to be resilient to pasted lists.
    repos_clean = repos_raw.strip().strip("'").strip('"')
    repo_tokens = re.findall(r"/[^\s,]+", repos_clean)
    if not repo_tokens:
        repo_tokens = [part.strip() for part in repos_clean.split(",") if part.strip()]

    # Preserve order and de-duplicate.
    seen: set[str] = set()
    repo_paths: list[pathlib.Path] = []
    for token in repo_tokens:
        if token in seen:
            continue
        seen.add(token)
        repo_paths.append(pathlib.Path(token).resolve())

    if not repo_paths:
        raise ValueError("No valid repository paths were provided")

    since = str(payload.get("since", "")).strip() or None
    max_points = int(payload.get("max_points", 180))
    top_sections = int(payload.get("top_sections", 8))
    top_files = int(payload.get("top_files", 10))

    if max_points < 2:
        raise ValueError("max_points must be >= 2")
    if top_sections < 1:
        raise ValueError("top_sections must be >= 1")
    if top_files < 1:
        raise ValueError("top_files must be >= 1")

    author_patterns = parse_author_patterns(str(payload.get("authors", "")).strip() or None)
    include_re = compile_optional_regex(str(payload.get("include_regex", "")).strip() or None)
    exclude_re = compile_optional_regex(str(payload.get("exclude_regex", "")).strip() or None)

    out: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []

    for repo in repo_paths:
        try:
            run_git(repo, ["rev-parse", "--is-inside-work-tree"])
            commits = collect_commit_stats(repo, since, author_patterns, include_re, exclude_re)
            if not commits:
                raw_commits = collect_commit_stats(repo, since, [], None, None)
                if raw_commits:
                    errors.append(
                        {
                            "repo": str(repo),
                            "error": (
                                "No commits matched active filters "
                                "(check authors/include/exclude regex and since range)."
                            ),
                        }
                    )
                else:
                    errors.append({"repo": str(repo), "error": "No commits found for selected since range."})
                continue
            out.append(build_dashboard_data(repo, commits, max_points, top_sections, top_files, include_re, exclude_re))
        except (GitError, OSError, ValueError, re.error) as exc:
            errors.append({"repo": str(repo), "error": str(exc)})

    cross = build_cross_repo_data(out) if out else {}
    return {"repos": out, "cross": cross, "errors": errors, "generated_at": dt.datetime.now(dt.timezone.utc).isoformat()}


def render_single_repo_html(data: dict[str, Any], plotly_src: str) -> str:
    payload = json.dumps(data)
    template = """<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Git History Dashboard</title>
  <script src=\"__PLOTLY_SRC__\"></script>
  <style>
    body { margin: 0; font-family: ui-sans-serif, system-ui, sans-serif; background: #101418; color: #e6edf3; }
    header { padding: 14px 18px; background: #182028; border-bottom: 1px solid #273341; }
    .meta { color: #9fb0c2; font-size: 14px; line-height: 1.4; overflow-wrap: anywhere; }
    .grid { display: grid; grid-template-columns: 1fr; gap: 14px; padding: 14px; }
    .card { background: #141b22; border: 1px solid #273341; border-radius: 10px; padding: 10px; }
    .plot { height: min(58vh, 520px); min-height: 360px; }
    @media (min-width: 1300px) { .grid.two-col { grid-template-columns: 1fr 1fr; } }
  </style>
</head>
<body>
  <header>
    <h2 style=\"margin: 0 0 6px 0\">Git History Dashboard</h2>
    <div class=\"meta\" id=\"meta\"></div>
  </header>

  <div class=\"grid\">
    <div class=\"card\"><div id=\"totals\" class=\"plot\"></div></div>
  </div>
  <div class=\"grid two-col\">
    <div class=\"card\"><div id=\"sizeBySection\" class=\"plot\"></div></div>
    <div class=\"card\"><div id=\"filesBySection\" class=\"plot\"></div></div>
  </div>
  <div class=\"grid two-col\">
    <div class=\"card\"><div id=\"commits\" class=\"plot\"></div></div>
    <div class=\"card\"><div id=\"churn\" class=\"plot\"></div></div>
  </div>

  <script>
    const data = __PAYLOAD__;
    function paddedRange(seriesMap) {
      const values = Object.values(seriesMap).flat().filter((v) => Number.isFinite(v));
      if (!values.length) return null;
      const min = Math.min(...values), max = Math.max(...values);
      if (min === max) return [Math.max(0, min - 1), max + 1];
      const pad = (max - min) * 0.05;
      return [Math.max(0, min - pad), max + pad];
    }
    const theme = {
      paper_bgcolor: '#141b22', plot_bgcolor: '#141b22', font: {color: '#e6edf3'},
      xaxis: {gridcolor: '#24303b'}, yaxis: {gridcolor: '#24303b'},
      margin: {l: 70, r: 36, t: 76, b: 84, pad: 6}
    };
    const baseLayout = {
      ...theme, hovermode: 'x unified',
      title: {x: 0.01, xanchor: 'left', font: {size: 17}},
      xaxis: {...theme.xaxis, automargin: true, tickfont: {size: 11}},
      yaxis: {...theme.yaxis, automargin: true, tickfont: {size: 11}},
    };

    document.getElementById('meta').textContent =
      `${data.repo} | commits: ${data.commit_count} | snapshots: ${data.snapshot_count} | generated: ${data.generated_at}`;

    Plotly.newPlot('totals', [
      {x: data.timeline.dates, y: data.timeline.total_bytes, type: 'scatter', mode: 'lines+markers', name: 'Total bytes', yaxis: 'y1'},
      {x: data.timeline.dates, y: data.timeline.total_files, type: 'scatter', mode: 'lines+markers', name: 'Total files', yaxis: 'y2'},
    ], {
      ...baseLayout, title: 'Repository Growth (Totals)',
      legend: {orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom', font: {size: 11}},
      xaxis: {...baseLayout.xaxis, rangeslider: {visible: true}},
      yaxis: {...baseLayout.yaxis, title: {text: 'Bytes', standoff: 8}},
      yaxis2: {...baseLayout.yaxis, title: {text: 'Files', standoff: 8}, overlaying: 'y', side: 'right'},
    }, {responsive: true});

    const sizeTraces = Object.entries(data.timeline.bytes_by_section).map(([name, ys]) => ({x: data.timeline.dates, y: ys, type: 'scatter', mode: 'lines', name}));
    Plotly.newPlot('sizeBySection', sizeTraces, {
      ...baseLayout,
      title: 'Size by Section (Top by final size)<br><sup style="color:#9fb0c2">Absolute totals can look flat at full range. Zoom or drag to inspect local growth.</sup>',
      margin: {...baseLayout.margin, r: 170, b: 66},
      legend: {orientation: 'v', x: 1.01, xanchor: 'left', y: 1, yanchor: 'top', font: {size: 10}},
      xaxis: {...baseLayout.xaxis, rangeslider: {visible: true}},
      yaxis: {...baseLayout.yaxis, title: {text: 'Bytes (absolute)', standoff: 8}, range: paddedRange(data.timeline.bytes_by_section)},
    }, {responsive: true});

    const filesTraces = Object.entries(data.timeline.files_by_section).map(([name, ys]) => ({x: data.timeline.dates, y: ys, type: 'scatter', mode: 'lines', name}));
    Plotly.newPlot('filesBySection', filesTraces, {
      ...baseLayout,
      title: 'File Count by Section (Top by final size)<br><sup style="color:#9fb0c2">Absolute totals can look flat at full range. Zoom or drag to inspect local growth.</sup>',
      margin: {...baseLayout.margin, r: 170, b: 66},
      legend: {orientation: 'v', x: 1.01, xanchor: 'left', y: 1, yanchor: 'top', font: {size: 10}},
      xaxis: {...baseLayout.xaxis, rangeslider: {visible: true}},
      yaxis: {...baseLayout.yaxis, title: {text: 'Files (absolute)', standoff: 8}, range: paddedRange(data.timeline.files_by_section)},
    }, {responsive: true});

    Plotly.newPlot('commits', [
      {x: data.activity.days, y: data.activity.commits, type: 'bar', name: 'Commits/day'},
      {x: data.activity.days, y: data.activity.commit_rolling_30d, type: 'scatter', mode: 'lines', name: '30d avg commits/day'},
    ], {
      ...baseLayout, title: 'Commit Rate Over Time',
      legend: {orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom', font: {size: 11}},
      xaxis: {...baseLayout.xaxis, rangeslider: {visible: true}},
      yaxis: {...baseLayout.yaxis, title: {text: 'Commits/day', standoff: 8}},
    }, {responsive: true});

    const deletionsNeg = data.activity.deletions.map((v) => -v);
    Plotly.newPlot('churn', [
      {x: data.activity.days, y: data.activity.additions, type: 'bar', name: 'Additions'},
      {x: data.activity.days, y: deletionsNeg, type: 'bar', name: 'Deletions (negative)'},
      {x: data.activity.days, y: data.activity.churn_rolling_30d, type: 'scatter', mode: 'lines', name: '30d avg churn (abs)'},
    ], {
      ...baseLayout, title: 'Churn Over Time', barmode: 'relative',
      legend: {orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom', font: {size: 11}},
      xaxis: {...baseLayout.xaxis, rangeslider: {visible: true}},
      yaxis: {...baseLayout.yaxis, title: {text: 'Lines changed', standoff: 8}},
    }, {responsive: true});
  </script>
</body>
</html>
"""
    return template.replace("__PLOTLY_SRC__", plotly_src).replace("__PAYLOAD__", payload)


def render_app_html(plotly_src: str) -> str:
    template = """<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Git Multi-Repo Dashboard</title>
  <script src=\"__PLOTLY_SRC__\"></script>
  <style>
    :root {{ --bg:#0f1419; --panel:#17212b; --panel2:#1f2d3a; --line:#2c3e50; --text:#e6edf3; --muted:#9fb0c2; --accent:#6fb1ff; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font-family: ui-sans-serif, system-ui, sans-serif; }}
    header {{ padding:16px 18px; border-bottom:1px solid var(--line); background:var(--panel); }}
    .controls {{ display:grid; grid-template-columns: 1fr 1fr 1fr; gap:10px; padding:12px 16px; border-bottom:1px solid var(--line); background:var(--panel2); }}
    .controls .wide {{ grid-column: span 3; }}
    label {{ display:block; font-size:12px; color:var(--muted); margin-bottom:4px; }}
    input {{ width:100%; padding:8px 10px; border-radius:8px; border:1px solid var(--line); background:#0f1a24; color:var(--text); box-sizing:border-box; }}
    button {{ padding:9px 13px; border-radius:8px; border:1px solid var(--accent); background:#103052; color:#d8ebff; cursor:pointer; }}
    .row {{ display:flex; gap:10px; align-items:end; }}
    .status {{ padding:10px 16px; color:var(--muted); border-bottom:1px solid var(--line); min-height:20px; white-space: pre-wrap; }}
    .content {{ padding:12px; display:grid; gap:12px; }}
    .card {{ background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:8px; }}
    .plot {{ height:min(58vh,520px); min-height:340px; }}
    .tabs {{ display:flex; gap:8px; flex-wrap:wrap; margin-bottom:8px; }}
    .tab {{ border:1px solid var(--line); background:#16222f; color:var(--text); border-radius:999px; padding:6px 10px; cursor:pointer; font-size:13px; }}
    .tab.active {{ border-color:var(--accent); color:#d8ebff; background:#173754; }}
    .error {{ color:#ffb0b0; font-size:13px; }}
    @media (max-width: 980px) {{ .controls {{ grid-template-columns: 1fr; }} .controls .wide {{ grid-column: span 1; }} }}
  </style>
</head>
<body>
  <header><h2 style=\"margin:0\">Git Multi-Repo Dashboard</h2></header>
  <div class=\"controls\">
    <div class=\"wide\">
      <label>Repository paths (comma-separated)</label>
      <input id=\"repos\" placeholder=\"/path/repo-a, /path/repo-b\" />
    </div>
    <div>
      <label>Authors filter (comma-separated regex)</label>
      <input id=\"authors\" placeholder=\"alice, bob@company.com\" />
    </div>
    <div>
      <label>Include path regex</label>
      <input id=\"include_regex\" placeholder=\"src/|docs/\" />
    </div>
    <div>
      <label>Exclude path regex</label>
      <input id=\"exclude_regex\" placeholder=\"^vendor/|\\.min\\.js$\" />
    </div>
    <div>
      <label>Since (git syntax)</label>
      <input id=\"since\" placeholder=\"24 months ago\" />
    </div>
    <div>
      <label>Max snapshot points</label>
      <input id=\"max_points\" type=\"number\" value=\"120\" min=\"2\" />
    </div>
    <div>
      <label>Top sections</label>
      <input id=\"top_sections\" type=\"number\" value=\"8\" min=\"1\" />
    </div>
    <div>
      <label>Top files</label>
      <input id=\"top_files\" type=\"number\" value=\"10\" min=\"1\" />
    </div>
    <div class=\"row\">
      <button id=\"run\">Analyze</button>
    </div>
  </div>
  <div id=\"status\" class=\"status\">Enter repo paths and click Analyze.</div>
  <div id=\"content\" class=\"content\"></div>

  <script>
    const statusEl = document.getElementById('status');
    const content = document.getElementById('content');

    function setStatus(text) {{ statusEl.textContent = text; }}

    function baseLayout() {{
      return {{
        paper_bgcolor: '#17212b',
        plot_bgcolor: '#17212b',
        font: {{color: '#e6edf3'}},
        xaxis: {{gridcolor: '#2c3e50', automargin: true}},
        yaxis: {{gridcolor: '#2c3e50', automargin: true}},
        margin: {{l: 70, r: 40, t: 84, b: 78, pad: 6}},
        hovermode: 'x unified',
        title: {{x: 0.01, xanchor: 'left', font: {{size: 17}}}},
      }};
    }}

    function paddedRange(seriesMap) {{
      const values = Object.values(seriesMap).flat().filter((v) => Number.isFinite(v));
      if (!values.length) return null;
      const min = Math.min(...values), max = Math.max(...values);
      if (min === max) return [Math.max(0, min - 1), max + 1];
      const pad = (max - min) * 0.05;
      return [Math.max(0, min - pad), max + pad];
    }}

    function sortTracesByLastValueDesc(traces) {{
      const lastNum = (t) => {{
        if (!Array.isArray(t.y) || t.y.length === 0) return Number.NEGATIVE_INFINITY;
        const v = Number(t.y[t.y.length - 1]);
        return Number.isFinite(v) ? v : Number.NEGATIVE_INFINITY;
      }};
      return [...traces].sort((a, b) => lastNum(b) - lastNum(a));
    }}

    function plotRepoCharts(target, repo) {{
      const grid = document.createElement('div');
      grid.innerHTML = `
        <div class=\"card\"><div id=\"${{target}}_totals\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_growth\" class=\"plot\"></div></div>
        <div class=\"card\">
          <div id=\"${{target}}_largest_meta\" style=\"color:#9fb0c2;font-size:12px;margin:2px 0 8px 2px;\"></div>
          <input id=\"${{target}}_largest_slider\" type=\"range\" min=\"0\" value=\"0\" style=\"width:100%;margin-bottom:8px;\" />
          <div id=\"${{target}}_largest\" class=\"plot\"></div>
        </div>
        <div class=\"card\"><div id=\"${{target}}_size\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_files\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_commits\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_churn\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_authors\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_heatmap\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_topbar\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"${{target}}_topline\" class=\"plot\"></div></div>
      `;
      content.appendChild(grid);

      const L = baseLayout();

      Plotly.newPlot(`${target}_totals`, [
        {{x: repo.timeline.dates, y: repo.timeline.total_bytes, type: 'scatter', mode: 'lines+markers', name: 'Total bytes', yaxis:'y1'}},
        {{x: repo.timeline.dates, y: repo.timeline.total_files, type: 'scatter', mode: 'lines+markers', name: 'Total files', yaxis:'y2'}},
      ], {{
        ...L,
        title: `Repository Footprint (Can Shrink): ${{repo.repo_name}}`,
        legend: {{orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom'}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Bytes'}}}},
        yaxis2: {{...L.yaxis, title: {{text: 'Files'}}, overlaying: 'y', side: 'right'}},
      }}, {{responsive:true}});

      Plotly.newPlot(`${target}_growth`, [
        {{x: repo.activity.days, y: repo.activity.cumulative_commits, type:'scatter', mode:'lines', name:'Cumulative commits'}},
        {{x: repo.activity.days, y: repo.activity.cumulative_churn, type:'scatter', mode:'lines', name:'Cumulative churn (ins+del)', yaxis:'y2'}},
      ], {{
        ...L,
        title: 'Cumulative Growth (Always Increases)',
        legend: {{orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom'}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text:'Commits'}}}},
        yaxis2: {{...L.yaxis, title: {{text:'Lines changed'}}, overlaying:'y', side:'right'}},
      }}, {{responsive:true}});

      const largestSnapshots = repo.largest_files_timeline || [];
      const largestSlider = document.getElementById(`${target}_largest_slider`);
      const largestMeta = document.getElementById(`${target}_largest_meta`);

      function renderLargestAt(index) {{
        if (!largestSnapshots.length) {{
          largestMeta.textContent = 'No largest-file snapshots available.';
          Plotly.newPlot(`${target}_largest`, [], {{...L, title: 'Top Largest Files Over Time'}}, {{responsive:true}});
          return;
        }}
        const idx = Math.max(0, Math.min(index, largestSnapshots.length - 1));
        const snap = largestSnapshots[idx];
        const commitShort = String(snap.commit || '').slice(0, 8);
        largestMeta.textContent = `Snapshot ${idx + 1}/${largestSnapshots.length} | ${snap.date} | commit ${commitShort}`;
        Plotly.react(`${target}_largest`, [
          {{
            x: snap.top.map((x) => x.bytes),
            y: snap.top.map((x) => x.file),
            type: 'bar',
            orientation: 'h',
            marker: {{color: '#6fb1ff'}},
            name: 'Bytes',
          }},
        ], {{
          ...L,
          title: 'Top Largest Files at Selected Time',
          yaxis: {{...L.yaxis, automargin: true}},
          xaxis: {{...L.xaxis, title: {{text: 'Bytes'}}}},
          showlegend: false,
        }}, {{responsive:true}});
      }}

      largestSlider.max = String(Math.max(0, largestSnapshots.length - 1));
      largestSlider.value = String(Math.max(0, largestSnapshots.length - 1));
      largestSlider.addEventListener('input', (e) => {{
        renderLargestAt(Number(e.target.value || 0));
      }});
      renderLargestAt(Number(largestSlider.value || 0));

      const sizeTraces = sortTracesByLastValueDesc(
        Object.entries(repo.timeline.bytes_by_section).map(([name, ys]) => ({{x: repo.timeline.dates, y: ys, type:'scatter', mode:'lines', name}}))
      );
      Plotly.newPlot(`${target}_size`, sizeTraces, {{
        ...L,
        title: 'Size by Section',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text:'Bytes (absolute)'}}, range: paddedRange(repo.timeline.bytes_by_section)}},
      }}, {{responsive:true}});

      const fileTraces = sortTracesByLastValueDesc(
        Object.entries(repo.timeline.files_by_section).map(([name, ys]) => ({{x: repo.timeline.dates, y: ys, type:'scatter', mode:'lines', name}}))
      );
      Plotly.newPlot(`${target}_files`, fileTraces, {{
        ...L,
        title: 'File Count by Section',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text:'Files (absolute)'}}, range: paddedRange(repo.timeline.files_by_section)}},
      }}, {{responsive:true}});

      Plotly.newPlot(`${target}_commits`, [
        {{x: repo.activity.days, y: repo.activity.commits, type:'bar', name:'Commits/day'}},
        {{x: repo.activity.days, y: repo.activity.commit_rolling_30d, type:'scatter', mode:'lines', name:'30d avg commits/day'}},
      ], {{
        ...L,
        title: 'Commit Rate',
        legend: {{orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom'}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text:'Commits/day'}}}},
      }}, {{responsive:true}});

      const deletionsNeg = repo.activity.deletions.map((v) => -v);
      Plotly.newPlot(`${target}_churn`, [
        {{x: repo.activity.days, y: repo.activity.additions, type:'bar', name:'Additions'}},
        {{x: repo.activity.days, y: deletionsNeg, type:'bar', name:'Deletions (negative)'}},
        {{x: repo.activity.days, y: repo.activity.churn_rolling_30d, type:'scatter', mode:'lines', name:'30d avg churn'}},
      ], {{
        ...L,
        title: 'Churn',
        barmode: 'relative',
        legend: {{orientation: 'h', x: 0, xanchor: 'left', y: 1.06, yanchor: 'bottom'}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text:'Lines changed'}}}},
      }}, {{responsive:true}});

      Plotly.newPlot(`${target}_authors`, [
        {{
          x: repo.authors.top_by_churn.map((x) => x.count),
          y: repo.authors.top_by_churn.map((x) => x.author),
          type: 'bar',
          orientation: 'h',
          name: 'Author churn',
        }},
        {{
          x: repo.authors.top_by_commits.map((x) => x.count),
          y: repo.authors.top_by_commits.map((x) => x.author),
          type: 'bar',
          orientation: 'h',
          name: 'Author commits',
          xaxis: 'x2',
          yaxis: 'y2',
        }},
      ], {{
        ...L,
        title: 'Top Authors (Churn + Commits)',
        grid: {{rows: 1, columns: 2, pattern: 'independent'}},
        margin: {{...L.margin, b: 60}},
        xaxis: {{...L.xaxis, title: {{text: 'Lines changed'}}}},
        yaxis: {{...L.yaxis, automargin: true}},
        xaxis2: {{...L.xaxis, title: {{text: 'Commits'}}}},
        yaxis2: {{...L.yaxis, automargin: true}},
        showlegend: false,
      }}, {{responsive:true}});

      Plotly.newPlot(`${target}_heatmap`, [
        {{
          z: repo.commit_heatmap.values,
          x: repo.commit_heatmap.hours,
          y: repo.commit_heatmap.weekdays,
          type: 'heatmap',
          colorscale: 'YlGnBu',
          colorbar: {{title: 'Commits'}},
        }},
      ], {{
        ...L,
        title: 'Commit Activity Heatmap (Weekday x Hour)',
        xaxis: {{...L.xaxis, title: {{text: 'Hour of day'}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Weekday'}}}},
      }}, {{responsive:true}});

      Plotly.newPlot(`${target}_topbar`, [
        {{x: repo.top_files.top_by_touches.map((x) => x.count), y: repo.top_files.top_by_touches.map((x) => x.file), type: 'bar', orientation: 'h', name: 'Touches'}},
      ], {{
        ...L,
        title: 'Top Files by Commit Touches',
        yaxis: {{...L.yaxis, automargin:true}},
      }}, {{responsive:true}});

      const topFileTraces = sortTracesByLastValueDesc(
        Object.entries(repo.top_files.cumulative_churn).map(([name, ys]) => ({{x: repo.top_files.days, y: ys, type:'scatter', mode:'lines', name}}))
      );
      Plotly.newPlot(`${target}_topline`, topFileTraces, {{
        ...L,
        title: 'Top Files by Churn Over Time (Cumulative)',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Cumulative line changes'}}}},
      }}, {{responsive:true}});
    }}

    function plotCrossRepo(cross) {{
      const wrapper = document.createElement('div');
      wrapper.innerHTML = `
        <div class=\"card\"><div id=\"cross_commits\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"cross_commits_cum\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"cross_churn\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"cross_churn_cum\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"cross_totals\" class=\"plot\"></div></div>
        <div class=\"card\"><div id=\"cross_authors\" class=\"plot\"></div></div>
      `;
      content.appendChild(wrapper);

      const L = baseLayout();
      const commitTraces = sortTracesByLastValueDesc(
        Object.entries(cross.commits_by_repo).map(([name, ys]) => ({{x: cross.days, y: ys, type:'scatter', mode:'lines', name}}))
      );
      Plotly.newPlot('cross_commits', commitTraces, {{
        ...L,
        title: 'Cross-Repo Commit Rate Comparison',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Commits/day'}}}},
      }}, {{responsive:true}});

      const commitCumTraces = sortTracesByLastValueDesc(Object.entries(cross.commits_by_repo).map(([name, ys]) => {{
        let running = 0;
        const cum = ys.map((v) => (running += v));
        return {{x: cross.days, y: cum, type:'scatter', mode:'lines', name}};
      }}));
      Plotly.newPlot('cross_commits_cum', commitCumTraces, {{
        ...L,
        title: 'Cross-Repo Cumulative Commits (Always Increases)',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Commits'}}}},
      }}, {{responsive:true}});

      const churnTraces = sortTracesByLastValueDesc(
        Object.entries(cross.churn_by_repo).map(([name, ys]) => ({{x: cross.days, y: ys, type:'scatter', mode:'lines', name}}))
      );
      Plotly.newPlot('cross_churn', churnTraces, {{
        ...L,
        title: 'Cross-Repo Churn Comparison',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Lines changed/day'}}}},
      }}, {{responsive:true}});

      const churnCumTraces = sortTracesByLastValueDesc(Object.entries(cross.churn_by_repo).map(([name, ys]) => {{
        let running = 0;
        const cum = ys.map((v) => (running += v));
        return {{x: cross.days, y: cum, type:'scatter', mode:'lines', name}};
      }}));
      Plotly.newPlot('cross_churn_cum', churnCumTraces, {{
        ...L,
        title: 'Cross-Repo Cumulative Churn (Always Increases)',
        margin: {{...L.margin, r: 170}},
        legend: {{orientation:'v', x:1.01, xanchor:'left', y:1, yanchor:'top', font:{{size:10}}}},
        xaxis: {{...L.xaxis, rangeslider: {{visible: true}}}},
        yaxis: {{...L.yaxis, title: {{text: 'Lines changed'}}}},
      }}, {{responsive:true}});

      const names = Object.keys(cross.final_bytes_by_repo);
      Plotly.newPlot('cross_totals', [
        {{x: names, y: names.map((n) => cross.final_bytes_by_repo[n]), type:'bar', name:'Final bytes'}},
        {{x: names, y: names.map((n) => cross.final_files_by_repo[n]), type:'bar', name:'Final files', yaxis:'y2'}},
      ], {{
        ...L,
        title: 'Cross-Repo Current Size Snapshot',
        barmode: 'group',
        legend: {{orientation:'h', x:0, xanchor:'left', y:1.06, yanchor:'bottom'}},
        yaxis: {{...L.yaxis, title: {{text:'Bytes'}}}},
        yaxis2: {{...L.yaxis, title: {{text:'Files'}}, overlaying:'y', side:'right'}},
      }}, {{responsive:true}});

      Plotly.newPlot('cross_authors', [
        {{
          x: cross.top_authors_by_churn.map((x) => x.count),
          y: cross.top_authors_by_churn.map((x) => x.author),
          type: 'bar',
          orientation: 'h',
          name: 'Churn',
        }},
      ], {{
        ...L,
        title: 'Cross-Repo Top Authors by Churn',
        yaxis: {{...L.yaxis, automargin: true}},
        xaxis: {{...L.xaxis, title: {{text: 'Lines changed'}}}},
        showlegend: false,
      }}, {{responsive:true}});
    }}

    function renderResult(result) {{
      content.innerHTML = '';

      if (result.errors && result.errors.length) {{
        const errCard = document.createElement('div');
        errCard.className = 'card';
        errCard.innerHTML = result.errors.map((e) => `<div class=\"error\">${{e.repo}}: ${{e.error}}</div>`).join('');
        content.appendChild(errCard);
      }}

      if (!result.repos || !result.repos.length) {{
        setStatus('No repositories produced data. Check filters/path inputs.');
        return;
      }}

      setStatus(`Loaded ${{result.repos.length}} repo(s). Generated at ${{result.generated_at}}`);

      const tabsCard = document.createElement('div');
      tabsCard.className = 'card';
      const tabs = document.createElement('div');
      tabs.className = 'tabs';
      tabsCard.appendChild(tabs);
      content.appendChild(tabsCard);

      let active = 'cross';
      const tabDefs = [{{id: 'cross', label: 'Cross Repo'}}].concat(result.repos.map((r, i) => ({{id: `repo_${{i}}`, label: r.repo_name, repo: r}})));

      function draw() {{
        while (content.children.length > 1) content.removeChild(content.lastChild);
        if (active === 'cross') plotCrossRepo(result.cross);
        else {{
          const idx = Number(active.split('_')[1]);
          plotRepoCharts(`repo_${{idx}}`, result.repos[idx]);
        }}
        for (const b of tabs.children) b.classList.toggle('active', b.dataset.id === active);
      }}

      for (const td of tabDefs) {{
        const b = document.createElement('button');
        b.className = 'tab' + (td.id === active ? ' active' : '');
        b.dataset.id = td.id;
        b.textContent = td.label;
        b.onclick = () => {{ active = td.id; draw(); }};
        tabs.appendChild(b);
      }}

      draw();
    }}

    async function analyze() {{
      const payload = {{
        repos: document.getElementById('repos').value,
        authors: document.getElementById('authors').value,
        include_regex: document.getElementById('include_regex').value,
        exclude_regex: document.getElementById('exclude_regex').value,
        since: document.getElementById('since').value,
        max_points: Number(document.getElementById('max_points').value || 120),
        top_sections: Number(document.getElementById('top_sections').value || 8),
        top_files: Number(document.getElementById('top_files').value || 10),
      }};
      setStatus('Collecting Git history... this may take a while for multiple repos.');
      content.innerHTML = '';

      try {{
        const response = await fetch('/api/analyze', {{method: 'POST', headers: {{'Content-Type': 'application/json'}}, body: JSON.stringify(payload)}});
        if (!response.ok) {{
          const txt = await response.text();
          throw new Error(txt || `HTTP ${{response.status}}`);
        }}
        const result = await response.json();
        renderResult(result);
      }} catch (err) {{
        setStatus(`Analyze failed: ${{err.message}}`);
      }}
    }}

    document.getElementById('run').addEventListener('click', analyze);
    document.getElementById('repos').value = window.location.pathname.includes('home') ? '' : '__DEFAULT_REPOS__';
  </script>
</body>
</html>
"""
    template = template.replace("{{", "{").replace("}}", "}")
    return template.replace("__PLOTLY_SRC__", plotly_src)


class DashboardHandler(BaseHTTPRequestHandler):
    plotly_src = "https://cdn.plot.ly/plotly-2.35.2.min.js"
    default_repos = ""

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path in {"/", "/index.html"}:
            html = render_app_html(self.plotly_src).replace("__DEFAULT_REPOS__", self.default_repos)
            self._send(HTTPStatus.OK, html.encode("utf-8"), "text/html; charset=utf-8")
            return
        self._send(HTTPStatus.NOT_FOUND, b"Not found", "text/plain; charset=utf-8")

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/api/analyze":
            self._send(HTTPStatus.NOT_FOUND, b"Not found", "text/plain; charset=utf-8")
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            payload = json.loads(raw.decode("utf-8"))
            result = analyze_repos(payload)
            body = json.dumps(result).encode("utf-8")
            self._send(HTTPStatus.OK, body, "application/json; charset=utf-8")
        except Exception as exc:  # broad to ensure API never crashes the server
            body = str(exc).encode("utf-8")
            self._send(HTTPStatus.BAD_REQUEST, body, "text/plain; charset=utf-8")


def run_generate(args: argparse.Namespace) -> int:
    repo = pathlib.Path(args.repo).resolve()
    output = pathlib.Path(args.output).resolve()

    try:
        run_git(repo, ["rev-parse", "--is-inside-work-tree"])
        author_patterns = parse_author_patterns(args.authors)
        include_re = compile_optional_regex(args.include_regex)
        exclude_re = compile_optional_regex(args.exclude_regex)
        commits = collect_commit_stats(repo, args.since, author_patterns, include_re, exclude_re)
    except (GitError, re.error, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if not commits:
        print("error: no commits found for selected range/filters", file=sys.stderr)
        return 2

    data = build_dashboard_data(
        repo,
        commits,
        args.max_points,
        args.top_sections,
        args.top_files,
        include_re,
        exclude_re,
    )
    html = render_single_repo_html(data, args.plotly_src)
    output.write_text(html, encoding="utf-8")
    print(f"Wrote dashboard: {output}")
    print("Open it in a browser to explore the graphs interactively.")
    return 0


def run_serve(args: argparse.Namespace) -> int:
    host = args.host
    port = args.port

    DashboardHandler.plotly_src = args.plotly_src
    DashboardHandler.default_repos = args.default_repos or ""

    server = ThreadingHTTPServer((host, port), DashboardHandler)
    url = f"http://{host}:{port}/"
    print(f"Serving Git dashboard at {url}")
    print("Use Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopped.")
    finally:
        server.server_close()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Git history dashboard (generate HTML or run local interactive server)")
    sub = parser.add_subparsers(dest="command")

    gen = sub.add_parser("generate", help="Generate a single static dashboard HTML")
    gen.add_argument("--repo", default=".", help="Path to the Git repository")
    gen.add_argument("--output", default="git-history-dashboard.html", help="Output HTML path")
    gen.add_argument("--since", default=None, help="Optional Git --since value")
    gen.add_argument("--authors", default=None, help="Comma-separated author regex filters")
    gen.add_argument("--include-regex", default=None, help="Regex for paths to include")
    gen.add_argument("--exclude-regex", default=None, help="Regex for paths to exclude")
    gen.add_argument("--max-points", type=int, default=180, help="Max snapshot points for growth charts")
    gen.add_argument("--top-sections", type=int, default=8, help="Number of top sections")
    gen.add_argument("--top-files", type=int, default=10, help="Number of top files")
    gen.add_argument("--plotly-src", default="https://cdn.plot.ly/plotly-2.35.2.min.js", help="Plotly script URL/path")

    srv = sub.add_parser("serve", help="Run interactive multi-repo dashboard server")
    srv.add_argument("--host", default="127.0.0.1", help="Bind host")
    srv.add_argument("--port", type=int, default=8765, help="Bind port")
    srv.add_argument("--default-repos", default="", help="Pre-fill repo input with comma-separated paths")
    srv.add_argument("--plotly-src", default="https://cdn.plot.ly/plotly-2.35.2.min.js", help="Plotly script URL/path")

    return parser


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = build_parser()

    # Backward-compatible legacy usage without subcommand: treat as generate args.
    if argv and argv[0] not in {"generate", "serve", "-h", "--help"}:
        argv = ["generate", *argv]
    if not argv:
        argv = ["serve"]
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.command == "serve":
        return run_serve(args)
    return run_generate(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
