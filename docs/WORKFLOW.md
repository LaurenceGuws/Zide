# Workflow + Docs Guide

This file explains how work and documentation are expected to flow in this
repository.

## Audience

- `README.md` and the docs explorer repo are customer-facing.
- This file is contributor/operator/agent-facing.

## Workflow

1. Read `docs/AGENT_HANDOFF.md` for current focus and constraints.
2. Read the owning TODO doc in `docs/todo/`.
3. Read only the design docs needed for the task.
4. Implement the change.
5. Update the owning docs.
6. Validate locally.
7. Commit only after approval, unless the user explicitly asks for a commit.

## Branching

- Do not implement directly on `main`.
- `main` is merge-only and should stay clean between validated milestones.
- Start active work on a feature branch from current `main`.
- If you create a branch, own it end-to-end: branch from current `main`, validate locally, merge back, and delete it after landing.
- For large architecture campaigns, a temporary "war branch" is allowed when it
  materially improves checkpoint discipline and keeps `main` clean between
  milestones.
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
- `ops/open_docs_browser.sh` — local launcher for the standalone docs explorer against this repo's docs surface.
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
- Prefer one clear authority per topic.
- If a doc defines the intended subsystem shape, boundary, contract, or design target, it belongs in `app_architecture/`.
- If a doc is architecture-adjacent communication such as a redesign plan, checkpoint, status note, diagram set, or release/design summary, it belongs in `app_architecture/`.
- If a doc is workflow, operator guidance, reference, research, review, or a non-authoritative execution queue, it belongs in `docs/`.
- If a topic is historical rather than current, move it under `docs/review/` or point to it from a current doc instead of duplicating it.
- If a topic is exploratory or reference-heavy rather than authoritative, place it under `docs/research/` or `docs/reference/`.
- Update the smallest doc that actually owns the information.

## Quick Placement Rules

- Contributor/operator workflow and active work queues: `docs/`
- Current architecture/design authority, diagrams, redesign plans, and architecture status communication: `app_architecture/`
- Research and technical reference: `docs/research/` and `docs/reference/`
- Historical review/investigation material: `docs/review/`
- Public/project-facing overview: `README.md` and the docs explorer repo
