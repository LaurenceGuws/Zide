# Windows Native Shell Integration

Date: 2026-03-25

Purpose: keep a short architectural note about advanced Windows shell
integration lanes that are outside the active Windows delivery scope.

## Status

- The supported Windows shell surface is now the packaged Win11 Explorer command
  lane documented in `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md`.
- Classic per-user Explorer verbs are legacy cleanup only and are no longer the
  supported product surface.
- Windows default terminal integration remains deferred indefinitely.

## Deferred Lanes

- Windows default terminal integration
- other package/COM/App Extension driven shell integrations beyond the current
  packaged Explorer command lane

## Why It Is Deferred

- These lanes are materially more complex than the current Explorer command
  path.
- They depend on heavier Windows-specific registration, identity, and shell
  integration mechanics.
- They are not required to ship a stable first Windows release.

## How To Treat This Doc

- Use this file as a scope boundary note, not an execution plan.
- Do not reopen the default-terminal lane unless product priorities explicitly
  change.
- For the active packaged Explorer work, use
  `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md`.
