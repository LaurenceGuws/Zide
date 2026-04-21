# Workflow + Docs Guide

This file explains how work and documentation are expected to flow in this
repository.

## Audience

- `README.md` and the docs explorer repo are customer-facing.
- This file is contributor/operator/agent-facing.

## Session Modes

This repo supports two operating modes. Use one mode per session.

### Single Operation Mode (default)

- One agent executes end-to-end with user collaboration.
- This is the existing repo workflow model.
- All sections below apply directly to this mode unless marked otherwise.

### Dual Agent Mode (Architect + Engineer)

Use this mode when the user explicitly wants a split between planning/review and
execution.

Use dual mode only for sprint-scale batches. If the active work is patch-sized
(for example one or two bounded renames/moves/callsite edits), execute it in
Single Operation Mode instead of opening a second agent loop.

Roles:

- User: sets product direction and approves ticket priorities.
- Architect agent: scopes, audits, ticket-plans, and reviews at architecture
  quality bar.
- Engineer agent: executes the ticket plan quickly with strict reporting.

Dual-mode lifecycle:

1. User and Architect agree goal and lane boundaries.
2. Architect reads current implementation + authority docs + relevant
   references and writes a ticketed day plan.
3. User starts Engineer session and instructs Engineer to read the authority
   docs and execute the ticket list.
4. Engineer response contract (every response):
   - `#DONE`: tickets completed in that response
   - `#OUTSTANDING`: remaining tickets
   - `COMMITS`: commits created in that response
5. User returns to Architect for review when ticket batch is cleared.
6. Architect reviews commits/notes/diffs/behavior with VT-core-level rigor
   expected for `src/terminal/core/**`.

Dual-mode doc ownership:

- Architect owns planning/review authority updates.
- Engineer owns execution progress against Architect ticket list.
- Both must keep queue state synchronized in owning docs.

## Default Operating Model

Treat the repo like one active campaign with ticket-style execution.

That means:

- `docs/AGENT_HANDOFF.md` tells you the current default campaign
- one owning TODO queue tells you what to do next
- architecture docs tell you what "correct" means
- you should be able to explain your work as "I am executing ticket X"

If you cannot name the active ticket, you are probably about to drift.

## Workflow

Single Operation Mode loop:

1. Read `docs/AGENT_HANDOFF.md` for current focus and constraints.
2. Read the owning TODO doc in `docs/todo/`.
3. Read only the design docs needed for that ticket.
4. Confirm the ticket scope, exit bar, and "do not do" rules.
5. If the lane is an architecture/performance/refactor campaign, finish the
   audit and queue-shaping work before starting code.
6. Implement the next queued change.
7. Update the owning docs.
8. Validate locally.
9. Commit only after approval, unless the user explicitly asks for a commit.

Dual Agent Mode loop:

1. Architect defines a bounded ticket batch with acceptance + non-goals.
2. Engineer executes tickets sequentially and reports `#DONE/#OUTSTANDING/COMMITS`.
3. Engineer updates owning queue docs after each meaningful checkpoint.
4. Architect reviews at ticket-batch boundary and either:
   - approves and advances batch
   - rejects with explicit corrective ticket(s)

Architect gate-closure rule (mandatory):

- After accepting a gate, Architect must do all three before declaring the lane ready:
  1. refocus owning queue docs to the next active milestone/batch
  2. update `docs/AGENT_HANDOFF.md` to that next focus
  3. issue a fresh engineer handoff prompt aligned to the refocused docs
- Do not leave the lane in "accepted but idle" state when clear next work exists.

Dual-session handover packet (mandatory after refocus):

- Architect must publish three aligned artifacts:
  1. active milestone in `docs/todo/**/implementation.md` marked `in_progress`
  2. matching milestone line in `docs/AGENT_HANDOFF.md`
  3. engineer execution contract in the lane entrypoint doc
- Users should not need to restate workflow mechanics when these three are aligned.

Dual-mode cadence rule:

- Prefer macro review chunks over per-milestone pauses.
- Engineer should continue through the full architect-defined batch unless:
  - `Blocked by Architect review needed: true`
  - the explicit batch super-gate is reached

Blocked-field naming by role:

- Architect reports: `Blocked by human review needed: true|false`
- Engineer reports: `Blocked by Architect review needed: true|false`

End-of-run summary labels (mandatory):

- Architect and Engineer summaries must include a `LABELS` block so humans can
  scan planned vs confirmed state quickly.
- Required label meanings:
  - `Planned`: queued/in-progress scope not yet validated
  - `Confirmed`: implemented and validated in this run
  - `Deferred`: explicitly moved out of the current batch
  - `Blocked`: cannot proceed without external decision/dependency
  - `ReviewRequired`: super-gate reached, architect verdict pending
  - `Accepted`: architect reviewed and approved
  - `Rejected`: architect reviewed and not approved
- Required gate tags:
  - `in_progress`
  - `super_gate`
  - `architect_review_pending`
  - `accepted`

## War-Campaign Prep

When the active lane is a "war" against a broad design problem, do not start
with opportunistic local fixes.

Preparation order:

1. fully audit the current war scope
2. identify explicit subcategories within that scope
3. fully audit one subcategory at a time
4. record findings plus fix queue / stop markers before code changes start

For each audited subcategory, the owning docs should answer:

- what the subcategory is
- why it is in scope
- what work is allowed there
- what work is forbidden there
- what the known offenders are
- what the next logical code cuts are

Only after that prep is complete should implementation begin.

## War Iteration Loop

Once the audit and subcategory map exist, use this loop:

1. choose the next logical-sized cut from the audited queue
2. implement it
3. validate it
4. record todo / authority progress
5. restart the loop from the audited queue

Do not replace this loop with ad hoc "validate -> audit -> tiny tweak" cycles.
The audit should lead the cuts, not trail them.

## Contract Pressure Rule

Treat platform pressure as a forcing function, not automatically as
platform-local scope.

That means:

- if Android exposes a flaw that lives in shared renderer/backend/runtime
  design, that flaw is shared-contract work
- if an issue is spread across supported renderers, it is in scope for the
  current war even if Android surfaced it first
- keep only truly platform-owned issues local to the platform lane

Examples of platform-local scope:

- Activity / window / IME host behavior
- Java/Kotlin/UI-thread ownership
- JNI handoff shape

Examples of shared-contract scope:

- render-thread work that cannot defend its existence
- frame submission policy
- font/atlas/scale hot-path cost
- present/invalidation policy
- layout/resize work on live draw paths

## Debug / Telemetry Exit Rule

Bug and performance investigations may add probes, logs, counters, capture
state, and temporary switches, but those artifacts do not get to remain by
default.

Before closing a task, classify each investigation artifact:

- **Correctness contract**: required for product behavior. Keep it always-on
  only if the cost is defensible, name it as product state, and document the
  owner.
- **Operator telemetry**: useful during normal support/development. Gate it
  behind config, log level, or build mode, and make the disabled cost close to
  zero.
- **Probe/debug capture**: investigation-only. It must be explicitly armed and
  must not run in ordinary product execution.

Delete anything that does not fit one of those categories.

Do not allow stale logs, debug structs, counters, env toggles, screenshots,
capture hooks, or fallback/probe paths to survive only because they helped solve
the last bug. If a field affects correctness, it must stop being called debug,
trace, or probe.

## Ticket Execution Rules

Every active task should have these five answers before code starts:

- What is the active ticket ID or queue item?
- Which doc owns the design truth?
- Which file or subsystem is under change?
- What is the acceptance criterion?
- What would count as drift?

Minimum ticket shape for execution:

- purpose
- owner docs
- scope
- acceptance criteria
- explicit non-goals / "do not do"

If the existing queue item does not provide those answers, improve the queue
before or while doing the work.

Code-movement rule:

- Implementation tickets must move product code, tests, or both unless the
  ticket is explicitly marked `doc-only` before execution.
- Documentation is evidence after implementation, not a substitute for it.
- If an implementation ticket can be completed by changing only markdown, the
  ticket is mis-scoped and must return to Architect for re-scope.
- Architecture campaigns may include one bounded audit/map ticket, but the
  next tickets must convert findings into code/test movement or stop.

## Historical Flattening Rule

- Keep active queue docs focused on: current target, acceptance, non-goals, and
  active gate decisions.
- Do not keep exhaustive per-iteration historical logs in active queue files
  once a campaign segment is accepted.
- Flatten historical detail into concise summaries and rely on:
  - `docs/review/**` archives for narrative history
  - `git log` for exact commit-level sequence
  - architecture authority docs for lasting design truth
- If an active queue file becomes long due to completed-history churn, the next
  architect refocus pass should compact it before opening another batch.

## Blocked / Done / Escalation Rules

Mark work done only when:

- the code change satisfies the ticket's acceptance criteria
- the owning queue reflects the new state
- local validation for that lane has been run

Mark work blocked when:

- the next step depends on a missing architecture decision
- the active lane is actually waiting on a different ticket
- local validation fails for reasons you cannot resolve inside the lane

Escalate instead of improvising when:

- two docs claim the same authority
- a quick fix would widen the wrong seam
- the active queue and the code reality materially disagree
- a lower-priority backend or platform is about to reshape the active contract

Weak-agent rule:

- do not invent a new lane because the current ticket feels hard
- either execute the named ticket, improve the ticket doc, or mark it blocked

## Branching

- Work on `main` by default unless the user explicitly asks for a branch.
- If a branch is explicitly requested, keep it reviewable and own it end-to-end:
  branch from current `main`, validate locally, merge back, and delete it after
  landing.
- A temporary "war branch" is allowed only when the user explicitly asks for it
  or explicitly approves it for a large architecture campaign.
- War-branch rule:
  - branch from the current `main`
  - keep small coherent checkpoint commits on the branch
  - define explicit milestones up front
  - merge back into `main` at each validated milestone instead of letting the
    branch drift across multiple unmerged milestones
  - after each milestone merge, continue from refreshed `main` and keep the
    next branch scope narrow
  - delete the branch once its current milestone work is landed

## Documentation Roles

- `AGENTS.md` — authoritative workflow rules and repo-specific operating constraints.
- `docs/AGENT_HANDOFF.md` — high-level current focus, constraints, and entrypoints for a fresh session.
- `docs/INDEX.md` — repo-local navigation map.
- `README.md` — customer-facing overview and primary links.
- `docs/todo/**` — active execution queues and implementation tracking that are not themselves architecture authority.
- `app_architecture/**.md` — current architecture/design authority plus architecture communication such as design plans, status checkpoints, diagrams, and release/design notes.
- `docs/reference/**` — contributor/operator-facing technical reference.
- `docs/research/**` — exploratory research and technical writeups.
- `docs/review/**` — historical audits, investigations, and review evidence.

Current focus rule:

- if `docs/AGENT_HANDOFF.md` names one indefinite architecture focus, treat
  that as the default priority across sessions
- do not substitute repo-wide reranks or side-war momentum for that focus
- future work in that lane should come from the owning architecture authority,
  not from opportunistic local cleanup
- when that focus is a long-running architecture campaign, keep one stable
  campaign identity and treat named subtopics as fronts within it, not as a
  string of new wars
- deferred older focus lanes should be recorded under `docs/deferred/` instead
  of remaining ambiguous "current" priorities

Doc-placement authority:

- This file is the normative doc-placement and doc-lifecycle policy.
- `AGENTS.md` and `docs/INDEX.md` should summarize or point here, not restate
  the full model independently.

## Documentation Rules

- Put current task progress in the owning todo or architecture doc, not in `docs/AGENT_HANDOFF.md`.
- If a doc contradicts code, fix the doc or remove the stale claim.
- If a tool, script, doc, or queue is no longer owned by this repo or no
  longer matches the live workflow, remove it instead of keeping a stale
  surface around "just in case."
- Prefer one clear authority per topic.
- Prefer one clear queue per active campaign.
- If a doc defines the intended subsystem shape, boundary, contract, or design target, it belongs in `app_architecture/`.
- If a doc is architecture-adjacent communication such as a redesign plan, checkpoint, status note, diagram set, or release/design summary, it belongs in `app_architecture/`.
- If a doc is workflow, operator guidance, reference, research, review, or a non-authoritative execution queue, it belongs in `docs/`.
- If a topic is historical rather than current, move it under `docs/review/` or point to it from a current doc instead of duplicating it.
- If a topic is exploratory or reference-heavy rather than authoritative, place it under `docs/research/` or `docs/reference/`.
- Update the smallest doc that actually owns the information.

## Queue Writing Rules

Write TODO queues so a weaker agent can execute them safely.

Good queue items:

- name one problem clearly
- link the owner docs directly
- say what counts as done
- say what not to touch
- make rerank conditions explicit

Bad queue items:

- broad motivational prose with no next action
- historical changelogs mixed with active execution instructions
- "clean this up" items with no boundary or owner
- backend or platform names used as a substitute for contract scope

## Review Gate Rules

Large architecture campaigns should define explicit review gates.

Each review gate should say:

- which tickets belong to the chunk
- what validation must run
- what the stop marker is
- what summary the reviewer expects back

Default reviewer handoff shape:

1. review chunk name
2. tickets completed
3. files changed
4. validation run
5. remaining risks
6. exact review questions

If a weaker agent cannot produce that handoff, the chunk is not ready for
review yet.

## Commit Rules

Default commit policy:

- keep commits small and coherent
- prefer one logical change per commit
- each commit should leave the tree buildable for that lane

For weaker agents:

- do not save work for one giant end-of-chunk commit
- make reviewable checkpoint commits on the active branch
- do not rewrite history unless explicitly asked
- stay on `main` unless the user explicitly asks for a branch

For reviewers/leads:

- accept work onto `main` only after the review gate for that chunk is met
- if a chunk is not reviewable, send it back to the branch instead of
  half-landing it on `main`

## Quick Placement Rules

- Contributor/operator workflow and active work queues: `docs/`
- Current architecture/design authority, diagrams, redesign plans, and architecture status communication: `app_architecture/`
- Research and technical reference: `docs/research/` and `docs/reference/`
- Historical review/investigation material: `docs/review/`
- Public/project-facing overview: `README.md` and the docs explorer repo
