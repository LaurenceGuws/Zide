# Agent Workflow (Zide)

## About the App

Zide aims to implement an IDE fully in Zig to the furthest extent possible that makes sense for our goals. The goal is a modern IDE for revamped workspace and micro-service development. A key driver: opening many microservices in a single workspace (e.g., 8 Java LSPs) can consume ~16GB RAM and slow everything down.

We design every piece with embedded-style resource constraints in mind. That means aggressive caching, smart lifecycle management for tooling (e.g., spin up LSPs, cache results, hot-reload only edited blocks/references, then shut them down), and a strong focus on raw responsiveness and performance.

Follow this workflow for every feature/task:

1. Read `docs/AGENT_HANDOFF.md`.
2. Use the handoff to confirm current focus and constraints.
3. Read the current todo file(s), reference implementations, and Zide's current implementation to learn best practices and feature-specific guidance.
4. Implement the feature.
5. Update all relevant docs to reflect changes and progress.
6. Inform the user how to test changes and debug until approved.
7. Default: do not commit until tests have been run and the user explicitly approves.
8. If the user explicitly says to commit, treat that instruction as approval and comply without blocking on test approval.
9. Work on `main` by default. Create a feature branch only when the task is large enough that isolated branch management materially reduces risk or review cost.
10. If you create a feature branch, you own it end-to-end: branch from current `main`, keep commits coherent, merge back into `main` after validation, and delete the branch once its work is on `main`.
11. Do not keep compatibility shims, dead paths, or duplicate seams purely to avoid a clean cut. If the old surface is wrong and removing it improves the architecture, replace it directly in a reviewable step.
12. Keep diffs reviewable; no file moves before baseline tests exist unless the move is itself the point of the approved change.
13. No behavior changes during extraction-only refactors; any semantic change must be separately scoped and test-driven.
14. Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.
15. Before any refactor, implement the replay harness, capture baseline goldens, and lock the fixture list as regression authority.
16. Once approved (or explicitly instructed to commit), commit each step labeled as the step header.
17. Return to the todo and suggest 3 next changes.

## Doc scope policy

- `README.md` and the hosted docs explorer are **customer-facing**.
- `docs/` is **contributor/operator-facing**: workflow, handoff, repo navigation, and active work queues.
- `app_architecture/` is **current technical authority**: designs, boundaries, and technical reasoning.
- `app_architecture/review/` is **historical evidence**: audits, investigations, and past reviews.
- `docs/AGENT_HANDOFF.md` is **high-level only**: focus, constraints, and entrypoint pointers for a fresh session.
- All task progress, checkpoints, and detailed changes live in the relevant `docs/todo/` files and `app_architecture/` docs.
- If research was done to create or update a TODO item, capture it in the relevant `app_architecture/` doc (not in handoff).
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
