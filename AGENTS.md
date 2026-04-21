# Agent Workflow (Zide)

## About the App

Zide aims to implement an IDE fully in Zig to the furthest extent possible that makes sense for our goals. The goal is a modern IDE for revamped workspace and micro-service development. A key driver: opening many microservices in a single workspace (e.g., 8 Java LSPs) can consume ~16GB RAM and slow everything down.

We design every piece with embedded-style resource constraints in mind. That means aggressive caching, smart lifecycle management for tooling (e.g., spin up LSPs, cache results, hot-reload only edited blocks/references, then shut them down), and a strong focus on raw responsiveness and performance.

## Session Mode Orchestrator

This repo supports two explicit session modes.

### Mode A: Single Operation Mode (Current Default)

- One agent executes end-to-end with direct user collaboration.
- This is the existing workflow model and remains fully valid.
- Use this mode unless the user explicitly requests dual-agent operation.

### Mode B: Dual Agent Mode (Architect + Engineer)

Roles:

- User: sets direction, decides priorities, approves milestone boundaries.
- Architect agent: plans, scopes, audits, reviews, and sets ticket quality bar.
- Engineer agent: executes a day plan quickly and reports ticket/commit status.

Flow:

1. User and Architect define a focused goal.
2. Architect reads implementation/docs/reference repos and writes a bounded day
   plan.
3. User starts Engineer session with explicit instruction to read authority docs
   and execute the ticket list.
4. Engineer loops with user through the day plan and must report per response:
   - `#DONE` tickets
   - `#OUTSTANDING` tickets
   - commits made in that response
5. User returns to Architect when tickets are cleared for review.
6. Architect performs deep review across:
   - commits
   - ticket progress notes
   - code diffs
   - behavior/contract impact
7. Architect review bar must match VT-core rigor used in
   `src/terminal/core/**` review depth.
8. After gate acceptance, Architect must immediately:
   - refocus `docs/AGENT_HANDOFF.md`
   - update the lane's active queue
   - produce a new engineer handoff prompt aligned to that focus

Mode discipline:

- Do not mix mode rules implicitly.
- Session must declare mode at start (`single` or `dual`).
- If mode is not explicit, use Single Operation Mode.

## Single Operation Mode (Indexed Existing Workflow)

Follow this workflow for every feature/task in Single Operation Mode:

1. Read `docs/AGENT_HANDOFF.md`.
2. Use the handoff to confirm current focus and constraints.
3. Read the active queue named by the handoff, reference implementations, and Zide's current implementation to learn best practices and feature-specific guidance.
4. If the lane is a broad architecture/performance/refactor campaign, perform the full audit and queue-shaping work before code changes start.
5. Implement the next logical-sized cut from the audited queue.
6. Update only the docs needed to preserve current focus or future technical decisions.
7. Inform the user how to test changes and debug until approved.
8. Default: do not commit until tests have been run and the user explicitly approves.
9. If the user explicitly says to commit, treat that instruction as approval and comply without blocking on test approval.
10. Work on `main` by default unless the user explicitly asks for a branch.
11. If the user explicitly asks for a branch, own it end-to-end: branch from current `main`, keep commits coherent, merge back into `main` after validation, and delete the branch once its work is on `main`.
12. A temporary "war branch" is allowed only when the user explicitly asks for it or explicitly approves it for a large architecture campaign; it must still merge into `main` at each validated milestone rather than drifting across multiple unmerged milestones.
13. Do not keep compatibility shims, dead paths, or duplicate seams purely to avoid a clean cut. If the old surface is wrong and removing it improves the architecture, replace it directly in a reviewable step.
14. Keep diffs reviewable; no file moves before baseline tests exist unless the move is itself the point of the approved change.
15. No behavior changes during extraction-only refactors; any semantic change must be separately scoped and test-driven.
16. Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.
17. Before any refactor, implement the replay harness, capture baseline goldens, and lock the fixture list as regression authority.
18. Once approved (or explicitly instructed to commit), commit each step labeled as the step header.
19. Prefer **small, scoped commits**: one logical change per commit when practical, each leaving the tree **buildable** (`zig build` at minimum; run `zig build test` when the lane touches test-covered code). Split doc-only updates from code. When a change cannot be split without a broken intermediate tree or a compatibility shim you are explicitly avoiding, use **one atomic commit** for that refactor rather than landing partial steps.
20. Return to the active queue and suggest the next changes.

## Active Tracking Policy

Active tracking must stay small.

- `docs/AGENT_HANDOFF.md` is the first-session pointer: current focus, read order,
  and hard constraints.
- Each lane may have one active queue file. For core work this is
  `docs/todo/core/ACTIVE_QUEUE.md`.
- The active queue is a small work board, not a ledger. Each item should name
  status, intent, primary files, and exit check.
- Long historical ledgers are archive evidence, not active work surfaces.
- Do not append routine ticket progress to `implementation.md` files.
- Commit messages and short checkpoint files are enough evidence for normal
  completed work.
- Update `app_architecture/` only when future code needs a durable technical
  rule or design reason.
- Do not let the tracking system become the work. A progress-doc-only commit
  needs an explicit user or architect reason.

## Strategic Goal Tags

Core strategic goal tags:

- `G1-HYGIENE`
- `G2-TOPOLOGY`
- `G3-CONSOLIDATION`
- `G4-VT`

Every commit must include at least one goal tag in the subject.
Untagged commits are not allowed.

## Delegation Standard

Delegated work must be executable without another planning pass.

Every work item handed to an Engineer agent should include:

- the target files or subsystem
- the allowed change type
- explicit non-goals
- validation commands
- stop conditions

Use dual-agent mode for throughput, not paperwork. If the batch is patch-sized,
run it in single-agent mode.

## War-Campaign Discipline

When a lane is a "war" against a design problem, do not drift into reactive
micro-iterations.

Preparation order:

1. fully audit the current war scope
2. identify explicit subcategories inside that scope
3. fully audit one subcategory at a time
4. write findings and fix queue before starting code

Implementation loop:

1. take the next logical-sized cut from the audited queue
2. implement it
3. validate it
4. record only the minimal active-queue or authority update needed
5. restart the loop from the audited queue

The audit should lead the code cuts, not trail them.

## Contract Pressure Rule

Treat platform pressure as a forcing function, not automatically as
platform-local scope.

- if Android exposes a flaw that exists across shared renderer/backend/runtime
  design, that flaw is shared-contract work
- if an issue is spread across supported renderers, it is in scope
- only truly platform-owned issues should remain local to the platform lane

## Continuous unattended workflow

- If the user explicitly requests unattended or overnight continuation, treat
  that as approval to keep executing sequential validated steps without
  waiting for another reply.
- In that mode, do not stop at the first clean checkpoint if there is still
  clear, locally-executable work in the active lane.
- Keep the branch reviewable by making small coherent commits at validated
  checkpoints rather than letting the branch sit as one huge uncommitted diff.
- Stop only when:
  - the current lane is honestly blocked by an external dependency or a risky
    product decision that cannot be inferred safely from repo authority
  - local validation fails and the failure cannot be resolved within the lane
  - the requested lane reaches a real validated endpoint rather than an
    artificial pause point
- When operating unattended, keep docs and architecture authority current at
  each meaningful checkpoint so the next session can resume without archaeology.

Current default priority rule:

- if `docs/AGENT_HANDOFF.md` names one indefinite architecture focus, that
  focus outranks opportunistic repo reranks and side-war momentum
- do not drift to another architecture lane unless the user explicitly directs
  it or the current focus is proven blocked by a stronger direct prerequisite
- current repo focus is whatever `docs/AGENT_HANDOFF.md` declares; do not
  hardcode a stale lane in this policy block
- treat that focus as one continuous scrutiny campaign; do not relabel each
  ranked front as a separate "war" unless the repo authority explicitly says
  the overall campaign itself has changed
- when an older long-running focus is paused, move the focus summary into
  `docs/deferred/` and remove it from session-default guidance

## Doc scope policy

- `README.md` and the docs explorer repo are **customer-facing**.
- `docs/` is **contributor/operator-facing**: workflow, handoff, repo navigation, active work queues, reference, research, and review material.
- `app_architecture/` is **current technical authority**: designs, boundaries, and technical reasoning.
- `docs/review/` is **historical evidence**: audits, investigations, and past reviews.
- `docs/AGENT_HANDOFF.md` is **high-level only**: focus, constraints, and entrypoint pointers for a fresh session.
- Active task state lives in the relevant active queue. Normal progress evidence
  lives in commit messages. Durable design rules live in `app_architecture/`.
- If research was done to create or update a TODO item, capture it in the relevant `app_architecture/` authority doc or `docs/research/` writeup (not in handoff).
- See `docs/WORKFLOW.md` for the normative doc-placement and docs-usage guide.

## CI policy

- This project does not use CI.
- CI is explicitly considered counter to the project workflow and should not be introduced.
- Do not add or suggest GitHub Actions, external CI pipelines, or CI-only gates.
- Validation is done locally through project build/test commands and manual verification.

## Logging ownership policy

- `./.zide.lua` logging configuration is owned by the agent, not the user.
- For every bug investigation, the agent **must** configure `./.zide.lua` logging to the minimum useful, bug-scoped signal set before asking the user for more data.
- The agent must proactively add/remove log tags per issue and keep log noise low while preserving required diagnostics.
- The agent must not ask the user to manually set `ZIDE_LOG` env vars or tune logging unless explicitly requested by the user.
- After debugging, the agent should leave `./.zide.lua` in a sensible default state (or clearly state the temporary logging changes made).

## Debug / telemetry cleanup policy

- Investigation code is temporary by default.
- After any bug fix, profiling pass, or device probe, classify every added log,
  counter, sample struct, debug field, env flag, probe path, and capture hook as
  one of:
  - **correctness contract**: required for product behavior; rename it as
    product state, document the owner, and keep it minimal
  - **operator telemetry**: useful for normal support/development; gate it
    behind config/log level/build mode with near-zero disabled cost
  - **probe/debug capture**: investigation-only; explicitly arm it, document how
    to remove or reuse it, and keep it off ordinary product paths
- Delete anything that does not fit one of those categories before marking the
  task done.
- Do not leave "just in case" logging, stale debug structs, profiling counters,
  compatibility probe paths, or one-off environment switches in hot/product
  paths after the issue is closed.
- Do not name correctness state as trace/debug/probe. If product behavior
  depends on it, its naming and module ownership must say so.
