# Wayland Present Research Topics

## Purpose

Operational research ledger for the Wayland present redesign. Each topic should
result in a temporary report under `docs/research/terminal/wayland_present/`.

After all topic reports exist, their findings should be consolidated into a
single technical writeup and then into an implementation plan.

## Report Directory

Temporary report root:

`docs/research/terminal/wayland_present/`

## Topic Format

Each topic below defines:

- the question
- why it matters
- the main seams it touches
- the primary local references
- the temporary report target

## Topics

### WP-01 SDL/Wayland/EGL Present Contract

- Question:
  - What does SDL actually do on Wayland/EGL for window surface creation,
    `SDL_GL_SwapWindow`, resize/display migration, and EGL context/surface
    ownership?
- Why it matters:
  - This is the narrowest stack boundary between Zide and the failing present
    seam.
- Seams:
  - SDL window lifecycle
  - EGL surface creation and current-context rules
  - swap behavior and display migration
- Primary refs:
  - `reference_repos/backends/sdl/src/video/SDL_egl.c`
  - `reference_repos/backends/sdl/src/video/wayland/SDL_waylandopengles.c`
  - `reference_repos/backends/sdl/src/video/wayland/SDL_waylandwindow.c`
  - `reference_repos/sdlwiki_md/SDL3/*EGL*.md`
- Report target:
  - `docs/research/terminal/wayland_present/wp_01_sdl_wayland_egl_contract.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_01_sdl_wayland_egl_contract.md`

### WP-02 Mesa EGL/Wayland Surface Semantics

- Question:
  - Under `EGL_BACK_BUFFER` + `EGL_BUFFER_DESTROYED`, what semantics should be
    assumed for swap, surface contents, and buffer lifetime on Mesa's EGL
    implementation?
- Why it matters:
  - This defines the durable correctness contract below SDL docs and above raw
    compositor behavior.
- Seams:
  - EGL surface state
  - swap destruction/preservation semantics
  - Wayland EGL surface behavior
- Primary refs:
  - `reference_repos/rendering/mesa/docs/egl.rst`
  - `reference_repos/rendering/mesa/src/egl/main/eglsurface.c`
  - `reference_repos/rendering/mesa/src/egl/main/eglcontext.c`
  - `reference_repos/rendering/khronos_refpages_md/EGL/*.md`
- Report target:
  - `docs/research/terminal/wayland_present/wp_02_mesa_egl_surface_semantics.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_02_mesa_egl_surface_semantics.md`

### WP-03 Reference Terminal Presentation Architectures

- Question:
  - How do the strongest native terminal implementations structure the boundary
    between terminal damage, GPU composition, and final presentation on
    Wayland-capable stacks?
- Why it matters:
  - We need a best-in-class comparison set before choosing the new Zide design.
- Seams:
  - offscreen vs default-framebuffer composition
  - damage/upload strategy
  - frame ownership and present discipline
- Primary refs:
  - `reference_repos/terminals/ghostty`
  - `reference_repos/terminals/foot`
  - `reference_repos/terminals/kitty`
  - `reference_repos/terminals/wezterm`
  - `reference_repos/terminals/rio`
- Report target:
  - `docs/research/terminal/wayland_present/wp_03_reference_terminal_architectures.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_03_reference_terminal_architectures.md`

### WP-04 Zide Present Seam Ownership

- Question:
  - Given the current stack, what are the correct ownership boundaries between
    VT publication, widget texture updates, renderer composition, and final
    presentation?
- Why it matters:
  - The redesign must simplify seam ownership rather than just adding a new
    render target.
- Seams:
  - `TerminalSession` publication
  - terminal widget texture planning
  - renderer composition and `endFrame()`
  - presentation acknowledgement and observability
- Primary refs:
  - `src/terminal/core/*`
  - `src/ui/widgets/terminal_widget_draw*.zig`
  - `src/ui/renderer.zig`
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
- Report target:
  - `docs/research/terminal/wayland_present/wp_04_zide_present_seam_ownership.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_04_zide_present_seam_ownership.md`

### WP-05 Damage, Upload, and Composition Strategy

- Question:
  - If Zide moves to an authoritative offscreen or hybrid presentation path,
    how should damage, texture uploads, and final composition interact so the
    stack remains both fast and reliable?
- Why it matters:
  - The winning design must stay lightweight and embedded-style, not simply
    brute-force full redraws.
- Seams:
  - partial texture upload
  - render-target invalidation
  - offscreen composition reuse
  - final present discipline
- Primary refs:
  - `reference_repos/terminals/ghostty`
  - `reference_repos/terminals/foot`
  - `reference_repos/terminals/kitty`
  - `src/ui/widgets/terminal_widget_draw_texture.zig`
  - `src/ui/renderer.zig`
- Report target:
  - `docs/research/terminal/wayland_present/wp_05_damage_upload_composition_strategy.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_05_damage_upload_composition_strategy.md`

### WP-06 Resize, Scale, and Display Migration Semantics

- Question:
  - How should the new presentation architecture behave across resize, drawable
    size changes, display moves, scale changes, and refresh-rate changes?
- Why it matters:
  - Current logs already show display hops, DPI changes, and drawable-size
    shifts; the design must stay correct under those transitions too.
- Seams:
  - SDL window events
  - drawable-size changes
  - render target recreation
  - pacing/swap-interval consequences
- Primary refs:
  - `reference_repos/backends/sdl/src/video/wayland/*`
  - `src/ui/renderer/window_init.zig`
  - `src/ui/renderer.zig`
  - `docs/AGENT_HANDOFF.md`
- Report target:
  - `docs/research/terminal/wayland_present/wp_06_resize_scale_display_migration.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_06_resize_scale_display_migration.md`

### WP-07 Observability and Validation Contract

- Question:
  - What debugging/validation hooks should survive the redesign so future
    renderer/present bugs can be isolated without turning logging into a timing
    side effect?
- Why it matters:
  - We need first-class diagnostics without contaminating the hot path.
- Seams:
  - target sampling
  - suspicious-frame probes
  - startup contract logging
  - replay/manual validation
- Primary refs:
  - `.zide.lua`
  - `src/ui/renderer.zig`
  - `src/ui/renderer/window_init.zig`
  - `docs/AGENT_HANDOFF.md`
- Report target:
  - `docs/research/terminal/wayland_present/wp_07_observability_validation_contract.md`
- Status:
  - completed
- Notes:
  - report landed at `docs/research/terminal/wayland_present/wp_07_observability_validation_contract.md`

## Consolidation Output

After all report targets exist, create:

`app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`

That writeup should:

- summarize each topic's findings
- compare viable design options
- name the best path forward
- list the migration sequence and validation plan
