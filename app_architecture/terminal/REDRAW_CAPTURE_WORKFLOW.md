Date: 2026-03-11

Purpose: make it cheap to turn a real terminal redraw repro into a replay-backed
authority once the current in-tree sample set is exhausted.

## When To Use This

Use this when:

- manual `nvim` / TUI behavior still looks wrong
- the current replay fixtures no longer expose the problem
- we need a fresh real non-clear reproducer before changing publication logic

Do not use this to invent synthetic targets when an existing replay fixture is
already authoritative.

## Live Log Readback

For manual `nvim` / TUI runs, prefer the scoped redraw log pair now enabled in
`./.zide.lua`:

- `terminal.ui.perf`
- `terminal.ui.redraw`

To summarize the latest pair quickly:

```bash
python3 tools/terminal_summarize_redraw_log.py
```

That prints the latest aggregate redraw record plus the latest row-local partial
plan span summary, which is the fastest way to compare:

- backend `damage_rows` / `damage_cols`
- live widget `plan_rows` / `plan_row_span` / `plan_col_span`
- row-local `spans=...`

## Capture Shape

For redraw/publication work, prefer a `harness_api` fixture:

- `baseline_input`
- one or more `output_chunks`

This is better than mixing everything into one `.vt` stream because:

- we can acknowledge a presented baseline cleanly
- we can model multi-packet redraws honestly
- we can assert damage only on the update phase

## Tool

Use:

- [terminal_make_redraw_fixture.py](/home/home/personal/zide/tools/terminal_make_redraw_fixture.py)
- [terminal_capture_pty.py](/home/home/personal/zide/tools/terminal_capture_pty.py)
- [terminal_capture_redraw_fixture.py](/home/home/personal/zide/tools/terminal_capture_redraw_fixture.py)

Capture raw PTY output first:

```bash
python3 tools/terminal_capture_pty.py \
  --output-file /tmp/nvim-baseline.txt \
  -- -- nvim
```

For a longer-lived single session with staged input and explicit output splits:

```bash
python3 tools/terminal_capture_pty.py \
  --output-file /tmp/nvim-full.txt \
  --checkpoint 0.30:/tmp/nvim-baseline.txt \
  --checkpoint 0.60:/tmp/nvim-update.txt \
  --checkpoint-quiet-ms 150 \
  --stdin-step 0.35:/tmp/nvim-keys.txt \
  --no-stdout \
  bash -lc 'nvim -u NONE -N "+set number relativenumber signcolumn=yes foldcolumn=2" /tmp/sample.txt'
```

This is now the preferred low-level path when separate baseline/update sessions
carry too much shared startup or teardown noise.

`terminal_capture_pty.py` now also honors `--rows` and `--cols`, so the PTY
viewport can match the intended replay fixture size instead of inheriting the
current terminal geometry by accident.

For scripted input or a second update phase:

```bash
python3 tools/terminal_capture_pty.py \
  --output-file /tmp/nvim-update-1.txt \
  --stdin-file /tmp/nvim-keys-1.txt \
  -- -- nvim
```

Then turn those captures into a harness-api fixture:

Example:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --name redraw_nvim_real_sample \
  --rows 40 \
  --cols 120 \
  --baseline-file /tmp/nvim-baseline.txt \
  --strip-baseline-prefix \
  --strip-shared-suffix \
  --update-file /tmp/nvim-update-1.txt \
  --update-file /tmp/nvim-update-2.txt
```

That writes:

- `fixtures/terminal/redraw_nvim_real_sample.json`
- `fixtures/terminal/redraw_nvim_real_sample.vt`

Without an observed-state file, the tool leaves `expected_damage` as a
placeholder. Fill it in from the observed current backend behavior first, then
update the golden.

To record the current observed publication contract for a fixture:

```bash
zig build test-terminal-replay -- \
  --fixture redraw_nvim_real_sample \
  --observe-only \
  --observed-file zig-cache/terminal-replay/redraw_nvim_real_sample.observed.json
```

That writes a clean JSON record of:

- `dirty`
- `damage`
- `viewport_shift_rows`
- `viewport_shift_exposed_only`

Use that file to fill the fixture's `expected_dirty`, `expected_damage`, and
viewport-shift assertions before updating goldens.

`--observe-only` is important for fresh fixture authoring because it records the
current backend contract without requiring the fixture's placeholder damage
assertions to pass first.

You can also feed the observed JSON back into the fixture generator directly:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --manifest-file /tmp/zide-redraw-captures/redraw_nvim_real_sample/manifest.json \
  --strip-baseline-prefix \
  --strip-shared-suffix \
  --observed-file zig-cache/terminal-replay/redraw_nvim_real_sample.observed.json
```

That rewrites the fixture with the observed redraw contract populated.

If you already have a staged capture manifest, rebuild from it directly:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --manifest-file /tmp/zide-redraw-captures/redraw_nvim_real_sample/manifest.json
```

That reuses the captured baseline/update files recorded in the manifest instead
of retyping the fixture inputs.

Or use the staged wrapper:

```bash
python3 tools/terminal_capture_redraw_fixture.py \
  --name redraw_nvim_real_sample \
  --rows 40 \
  --cols 120 \
  --cwd /path/to/project \
  --no-stdout \
  --strip-baseline-prefix \
  --strip-shared-suffix \
  --hydrate-observed \
  --update-goldens \
  --validate \
  --baseline-shell 'nvim' \
  --update-shell 'nvim'
```

That:

- records the baseline capture
- records each update capture
- writes the harness-api fixture skeleton
- optionally runs the replay runner and writes the observed redraw contract back into the fixture
- can optionally update the fixture golden and validate the fixture immediately
- keeps intermediate capture files under `/tmp/zide-redraw-captures/<name>/`
- writes a `manifest.json` beside those captures so the exact command/cwd/input recipe stays attached to the reproducer
- is the preferred path when capturing a fresh live `nvim`/TUI redraw repro

For a true single-session capture, use the wrapper directly over one long-lived
PTY run:

```bash
python3 tools/terminal_capture_redraw_fixture.py \
  --name redraw_nvim_real_single_session \
  --rows 40 \
  --cols 120 \
  --fixture-dir fixtures/terminal \
  --cwd /path/to/project \
  --no-stdout \
  --single-session-shell 'nvim -u NONE -N "+set number relativenumber signcolumn=yes foldcolumn=2" sample.txt' \
  --single-session-stdin-script /tmp/nvim-redraw.script \
  --single-session-baseline-at 0.80 \
  --single-session-update-at 1.20 \
  --checkpoint-quiet-ms 150 \
  --hydrate-observed \
  --update-goldens \
  --validate
```

This is the preferred path for real `nvim` movement probes because it keeps one
editor session alive and splits baseline vs redraw with timed checkpoints
instead of restarting `nvim` for each phase.

Useful options:

- `--cwd` to run every capture phase in the same project directory
- `--no-stdout` to keep capture quiet while still recording raw PTY bytes
- `--baseline-stdin-file` / `--update-stdin-file` for scripted keystroke phases
- `--baseline-stdin-script` / `--update-stdin-script` for richer timed staged-input scripts
- `--single-session-shell` / `--single-session-cmd` to capture one long-lived PTY session
- `--single-session-stdin-file` / `--single-session-stdin-script` for scripted single-session input
- `--single-session-baseline-at` / `--single-session-update-at` to split one session into baseline and redraw chunks
- `--checkpoint-quiet-ms` to control how long a due single-session checkpoint waits for output to go idle before flushing
- `--strip-baseline-prefix` to remove the shared startup prefix from each update capture before writing `output_chunks`
- `--strip-shared-suffix` to remove shared teardown bytes after prefix stripping, which helps when separate PTY sessions share the same quit path
- `--hydrate-observed` to run replay immediately and fill `expected_dirty`, `expected_damage`, and viewport-shift assertions from the current backend output
- `--update-goldens` to update the fixture golden immediately after generation/hydration
- `--validate` to run the fixture immediately after generation/hydration

Single-session capture options in `terminal_capture_pty.py`:

- `--stdin-step <seconds>:<file>` to inject scripted input later in the same PTY session
- `--stdin-script <path>` for richer staged input without many temp files
- `--checkpoint <seconds>:<output-file>` to write the bytes captured since the previous checkpoint
- `--checkpoint-quiet-ms <ms>` to wait for a short idle window before a due checkpoint flushes, which helps avoid slicing active repaint bursts in half

`--stdin-script` format:

```text
# <seconds> <file|text|hex> <payload>
0.35 text j
0.55 text :
0.65 text wq\\r
0.80 hex 1b 5b 42
1.00 file /tmp/nvim-extra-keys.bin
```

Notes:

- `text` payloads use Python-style escapes, so `\\r`, `\\n`, and `\\x1b` work.
- `hex` payloads accept space-separated or compact hex bytes.
- Scripted actions are merged with any `--stdin-step` entries and sorted by time.

Use generous timing gaps. The goal is not perfect frame-accurate tracing; it is
to split one live TUI session into a stable baseline chunk and a later redraw
delta without restarting the app.

Important guardrail:

- fixture generation now fails if prefix/suffix stripping would erase an update
  chunk completely
- fixture generation also fails if an unstripped update chunk is empty
- treat that as evidence that the staged capture timing is wrong for that repro,
  not as a valid "no-op redraw" authority

Current limitation:

- `--hydrate-observed` currently requires `--fixture-dir fixtures/terminal`, because the replay build step only discovers fixtures from the repo fixture root.
- `--update-goldens` and `--validate` currently have the same fixture-root requirement for the same reason.

## Authoring Rules

1. Keep the fixture real.
   Use captured terminal bytes from an actual TUI state transition, ideally from
   `terminal_capture_pty.py`.

2. Keep the viewport small enough to inspect.
   Trim rows/cols to the smallest viewport that still reproduces the bug.

3. Preserve packet boundaries when they matter.
   If the bad publication only appears across multiple writes, keep separate
   `--update-file` chunks.

4. Capture current behavior before fixing it.
   The replay fixture must first lock what the backend actually does today.

5. Only then change publication logic.

## Validation

After filling in `expected_damage`, run:

```bash
zig build test-terminal-replay -- --fixture <name> --update-goldens
zig build test-terminal-replay -- --fixture <name>
```

Then run the broader local validation set before committing the behavior change.
