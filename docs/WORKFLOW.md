# Workflow + Docs Guide

This doc explains how workflow and documentation are intended to be used.

## Workflow (agent + contributors)
- **Primary source of truth** for tasks is the relevant todo in `app_architecture/**/_todo.yaml`.
- **Handoff docs** (`docs/AGENT_HANDOFF.md`, `docs/AGENT_HOVER.md`) are **high‑level only**.
- **Progress tracking** belongs in todo files and app_architecture docs, not in handoff.
- **Research notes** that informed a todo item must live in the relevant `app_architecture/` doc.
- **Implementation** follows AGENTS.md workflow: read handoff → read todo → implement → update docs → tests → approval → commit.

## Branching workflow
- `main` is the default working branch.
- Create a feature branch only for larger changes where isolated branch management materially improves safety or reviewability.
- If a feature branch is created, the agent owns the whole lifecycle:
  - branch from current `main`
  - keep commits coherent and scoped
  - validate locally
  - merge back into `main`
  - delete the branch after its work is on `main`
- Do not preserve obsolete APIs or duplicate code paths just to avoid a direct cut. Prefer clean replacement over compatibility scaffolding when the old surface is holding the design back.

## Docs roles (what goes where)
- `AGENTS.md`: authoritative workflow rules.
- `docs/AGENT_HANDOFF.md`: short entrypoint for the next session (focus, constraints, where to look).
- `docs/AGENT_HOVER.md`: high‑level editor context only; can be removed if redundant.
- `docs/INDEX.md`: map of docs and where to look.
- `app_architecture/*_todo.yaml`: task tracker and status for each area.
- `app_architecture/**.md`: design decisions, research notes, and architecture guidance.
- `README.md`: user‑facing overview and quick start.

## Updating docs
- If a change **advances a task**, update the matching todo entry.
- If a change **adds research or design decisions**, update the relevant app_architecture doc.
- If a change **changes focus or constraints**, update the handoff doc at a high level.
- Avoid duplicating the same details across multiple docs.

## Doc drift policy
- If a doc contradicts code, fix or remove it.
- Prefer updating the smallest doc that owns the information.
