# Windows Native Chrome Reference Crosscheck

Date: 2026-03-20

Purpose: compare the most relevant terminal references for Zide's Windows-native
terminal chrome work, especially around integrated titlebars, caption behavior,
and the next Snap Layout follow-up.

This note is research support, not design authority. Current execution and
acceptance still belong in:

- `docs/todo/windows/implementation.md`
- `app_architecture/APP_LAYERING.md`

## Why These References

The current Windows terminal-chrome lane needs two different kinds of guidance:

1. native Win11 truth
2. product/architecture quality

No single reference is best at both.

For Zide, the useful split is:

- Windows Terminal for native Win11 caption, drag-bar, and DWM behavior
- WezTerm for cross-platform architecture and polish bar
- Ghostty for product taste and config-policy discipline, but not as a primary
  Windows implementation authority

Secondary references like VS Code/VSCodium, Tabby, and Hyper are still useful,
but mainly for titlebar/action layout and user-experience expectations. They are
not the best source of truth for Win32 non-client behavior.

## 1. Windows Terminal

Primary local reference:

- `reference_repos/terminals/windows_terminal/src/cascadia/WindowsTerminal/NonClientIslandWindow.cpp`

### Strong points

- Strongest local authority for Win11-native titlebar/caption behavior.
- Uses a dedicated child drag/input sink window over the titlebar region.
- Explicitly returns native hit-test results like `HTCAPTION`, `HTTOP`,
  `HTMINBUTTON`, `HTMAXBUTTON`, and `HTCLOSE`.
- Handles caption-button hover/press/release manually while still preserving the
  native non-client contract.
- Uses `DwmExtendFrameIntoClientArea(...)` as part of a real Windows custom
  titlebar strategy.
- Treats Snap Layout hover as part of a broader custom non-client design, not as
  a one-off maximize-button trick.

### Weak points

- Heavily Windows-specific.
- More XAML/WinUI/island-oriented than Zide wants structurally.
- Easy to cargo-cult the mechanism and overfit Zide to a Windows-only design if
  we copy too much instead of extracting the reusable idea.

### What Zide should borrow

- The persistent drag/input sink concept.
- The idea that Snap hover belongs to a full caption contract.
- The split between:
  - native caption semantics
  - app-owned visual presentation

### What Zide should not borrow

- The larger WinUI/XAML hosting model.
- Windows-specific UI composition decisions that would leak into shared app
  layering.

## 2. WezTerm

Primary local references:

- `reference_repos/terminals/wezterm/docs/config/lua/config/window_decorations.md`
- `reference_repos/terminals/wezterm/docs/config/lua/config/integrated_title_button_style.md`
- `reference_repos/terminals/wezterm/docs/config/lua/config/win32_system_backdrop.md`
- `reference_repos/terminals/wezterm/window/src/os/windows/window.rs`

### Strong points

- Better fit for Zide's architecture and quality bar than Windows Terminal.
- Keeps the chrome/config surface disciplined:
  - `window_decorations`
  - integrated title button style/alignment/color
  - Windows backdrop configuration
- Explicitly warns that removing native resize/titlebar semantics too
  aggressively causes real platform problems.
- Has a clean split between:
  - windowing/backend mechanics
  - GUI rendering/presentation
  - config policy
- On Windows, it still participates in Snap-related behavior by returning
  `HTMAXBUTTON` when appropriate, but it does so inside a broader windowing
  backend instead of scattering hacks through draw code.

### Weak points

- Not as authoritative as Windows Terminal for the deepest Win11 caption edge
  cases.
- More conservative visually than some modern Windows-native apps.
- Good at integrated controls, but not the strongest reference for "maximally
  native" Win11 titlebar semantics.

### What Zide should borrow

- The architecture split: window backend owns native mechanics; UI owns visual
  presentation.
- The config discipline for integrated controls and backdrop/material choices.
- The quality bar around not breaking resize/minimize/drag semantics just to get
  a cleaner look.

### What Zide should not borrow

- Any temptation to stop at "good enough custom buttons" when Win11-specific
  behavior still feels off.

## 3. Ghostty

Primary local references:

- `reference_repos/terminals/ghostty/src/config/Config.zig`
- `reference_repos/terminals/ghostty/src/apprt/gtk/class/window.zig`

### Strong points

- Strong product taste.
- Good example of treating titlebar/decorations as product policy, not just a
  technical detail.
- Clear config thinking around decoration/titlebar styles and host-specific
  behavior.
- Helpful for deciding where policy belongs, especially on non-Windows hosts.

### Weak points

- Not a strong Windows-native titlebar reference.
- Most interesting titlebar work here is GTK/Linux and macOS specific.
- Useful for "how to think about chrome as product UX", but weak for Win11
  caption/Snap implementation details.

### What Zide should borrow

- Product rigor and taste.
- Clear configuration boundaries around chrome policy.

### What Zide should not borrow

- Host-specific titlebar assumptions as if they generalize to Windows.
- Implementation details for Win11-native caption behavior.

## Secondary References

## VS Code / VSCodium

VSCodium is still useful, but only as a secondary reference.

### Strong points

- Good for titlebar command density and general IDE usability expectations.
- Good for seeing what users accept in a custom top bar for an IDE product.

### Weak points

- It sits behind Electron's window abstractions, so it is not the clearest
  source of truth for Win32 non-client behavior.
- It can easily bias us toward web-layout solutions for problems that are
  really native-window problems.

### Practical conclusion

- Good reference for future IDE/editor titlebar action layout.
- Weak primary reference for terminal integrated caption/Snap behavior.

## Electron Apps More Broadly

Relevant local references:

- `reference_repos/terminals/tabby/app/lib/window.ts`
- `reference_repos/terminals/hyper/app/ui/window.ts`

Electron is useful, but dangerous if used as the main authority for this lane.

### Why it helps

- It shows common modern app patterns for:
  - hidden titlebars
  - titlebar overlays
  - command placement in custom top bars
- It is good for understanding what users already see in Windows apps.

### Why it can mislead

- It hides or abstracts the Win32 non-client seam.
- It encourages thinking in terms of overlay regions and web layout rather than
  native caption ownership.
- Apps like Hyper and Tabby are informative about UX direction, but not ideal as
  technical authorities for getting Snap Layouts, caption hit-testing, and
  restore/maximize behavior exactly right.

### Practical conclusion

- Keep Electron references secondary.
- Use them for IDE/editor titlebar action design and visual density.
- Do not use them as the primary authority for terminal caption interop.

## Current Recommendation For Zide

Use a split reference strategy:

1. Windows Terminal
   - primary authority for:
     - Snap Layout hover
     - caption hit-testing
     - drag/input sink design
     - DWM/custom frame behavior

2. WezTerm
   - primary authority for:
     - architecture split
     - integrated control config design
     - "native enough without becoming Windows-only" quality bar

3. Ghostty
   - tertiary authority for:
     - product taste
     - config-policy discipline

4. VS Code / VSCodium / Electron apps
   - secondary authority only for:
     - IDE/editor titlebar action placement
     - command density
     - general UX expectations

## Direct Implications For Current Zide Work

### Terminal integrated chrome

- Keep the accepted integrated terminal chrome baseline stable.
- Treat Win11 Snap Layout hover as a separate follow-up, not as permission to
  destabilize maximize/drag/right-click behavior again.
- Re-approach Snap with a persistent Windows-Terminal-like drag/input sink
  created once and resized with titleband geometry changes.

### IDE/editor titlebar work

- Do not reuse terminal integrated chrome wholesale.
- Use VS Code/VSCodium and Electron apps as lightweight references for action
  placement only.
- Keep the actual shell/platform integration below product composition, in line
  with `app_architecture/APP_LAYERING.md`.

## Bottom Line

If the question is "what should teach Zide how to be a real Win11 terminal
window?", the answer is Windows Terminal first and WezTerm second.

If the question is "what should teach Zide how to make the top band feel like a
high-quality modern app?", the answer is WezTerm first, then selective VS
Code/VSCodium/Electron inspiration for IDE/editor command placement.

If the question is "will Electron blind us?", the answer is:

- not if we keep it in the right box
- yes if we start treating it as the primary authority for native caption
  behavior
