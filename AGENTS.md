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
7. Commit each step labeled as the step header.
8. Return to the todo and suggest 3 next changes.
