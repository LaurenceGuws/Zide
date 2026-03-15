# Workflow + Docs Guide

This file explains how work and documentation are expected to flow in this
repository.

## Audience

- `README.md` and the hosted docs explorer are customer-facing.
- This file is contributor/operator/agent-facing.

## Workflow

1. Read `docs/AGENT_HANDOFF.md` for current focus and constraints.
2. Read the owning TODO doc in `app_architecture/`.
3. Read only the design docs needed for the task.
4. Implement the change.
5. Update the owning docs.
6. Validate locally.
7. Commit only after approval, unless the user explicitly asks for a commit.

## Branching

- `main` is the default branch.
- Create a feature branch only when isolation materially improves safety or reviewability.
- If you create a branch, own it end-to-end: branch from current `main`, validate locally, merge back, and delete it after landing.

## Documentation Roles

- `AGENTS.md` — authoritative workflow rules and repo-specific operating constraints.
- `docs/AGENT_HANDOFF.md` — high-level current focus, constraints, and entrypoints for a fresh session.
- `docs/INDEX.md` — repo-local navigation map.
- `README.md` — customer-facing overview and primary links.
- `app_architecture/*todo*.md` and `*_TODO.md` surfaces — active task tracking and status.
- `app_architecture/**.md` — current architecture, design, and research authority.
- `app_architecture/review/**` — historical audits, investigations, and review evidence.

Doc-placement authority:

- This file is the normative doc-placement and doc-lifecycle policy.
- `AGENTS.md` and `docs/INDEX.md` should summarize or point here, not restate
  the full model independently.

## Documentation Rules

- Put current task progress in the owning todo or architecture doc, not in `docs/AGENT_HANDOFF.md`.
- If a doc contradicts code, fix the doc or remove the stale claim.
- Prefer one clear authority per topic.
- If a topic is historical rather than current, move it under `app_architecture/review/` or point to it from a current doc instead of duplicating it.
- Update the smallest doc that actually owns the information.

## Quick Placement Rules

- Contributor/operator workflow right now: `docs/`
- Current architecture or active queues: `app_architecture/`
- Historical review/investigation material: `app_architecture/review/`
- Public/project-facing overview: `README.md` and the hosted docs explorer
