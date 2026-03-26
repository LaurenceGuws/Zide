# Win11 Explorer Command Multi-Select

Date: 2026-03-25

Purpose: capture what the local Windows Terminal shell-extension refs actually
show about Explorer selection handling and menu reduction, and turn that into a
practical Zide menu contract.

## What Is Clearly Evidenced

- Windows Terminal's Explorer command is a single `IExplorerCommand` entry, not
  a menu tree of many registered commands.
- The command resolves the target from the selection/site chain, but when a
  selection is present it explicitly reads `GetCount()` and uses only
  `GetItemAt(0)` from the shell-item array.
- The command does not implement subcommands; `EnumSubCommands()` returns
  `E_NOTIMPL`.
- Visibility is based on item attributes, not on a rich multi-select policy:
  filesystem items are enabled, compressed items are hidden.
- The Windows Terminal property-sheet handler has a separate, explicit
  single-selection gate: it only considers itself for selections of one file.

## What Is Uncertain

- The local Windows Terminal refs do not show a polished multi-select menu
  reduction strategy for Explorer commands.
- They do not show a rule for:
  - homogeneous multi-file selection
  - mixed file + folder selection
  - when a top-level submenu should collapse to a direct command
- They also do not prove whether Explorer itself reduces menus before the COM
  object sees the selection, or whether that reduction must be implemented by
  the extension.

## Practical Zide Options

The current Zide direction that best matches the user goal is:

- if multiple relevant actions exist, show a top-level `Zide` submenu
- if only one relevant action exists, show the direct command instead
- if the selection is mixed or unsupported, hide the menu item rather than
  guessing

That yields the current Zide contract:

1. single file and multiple files -> `Zide` submenu
1. single folder -> `Zide` submenu
1. multiple folders -> `Zide` submenu with terminal only
1. folder background -> `Zide` submenu
1. mixed file+folder selection -> hidden

The only part above that is directly evidenced by the refs is the conservative
single-target behavior. The submenu flattening rule is the Zide product
proposal, not something the refs explicitly prove.

## Reference Files

- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.h`
- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/OpenTerminalHere.cpp`
- `dev_references/terminals/windows_terminal/src/propsheet/PropSheetHandler.cpp`
- `dev_references/terminals/windows_terminal/src/cascadia/ShellExtension/WindowsTerminalShellExt.vcxproj`

## Zide Follow-Up

- Keep the packaged Win11 Explorer lane as the only active Windows shell
  surface.
- Implement multi-select as an explicit product contract, not as accidental
  first-item behavior.
- Prefer a reduction rule that is deterministic and easy to explain in the
  docs and installer output.
