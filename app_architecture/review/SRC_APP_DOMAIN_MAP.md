# `src/app` Domain Map

Date: 2026-03-10

Purpose: define the stable ownership map for `src/app` before moving files.

This is the authority for `FL-APP-01`. File moves should follow this map instead of preserving the current suffix-driven flat layout.

## Why `src/app` Needs A Domain Map

Current `src/app` shape is the main remaining folder-level structural smell in the repo:
- too many flat files
- too many suffix-oriented names (`*_runtime`, `*_frame`, `*_hooks_runtime`)
- weak folder-level ownership
- high navigation cost for runtime, terminal, editor, tab, and config behavior

The goal is not deep nesting. The goal is to make `src/app` read like the app host layer it is.

## Target Subtrees

### `src/app/core/`

Owns the app host root and shared runtime shell.

Put here:
- `app_state.zig`
- `app_state_types.zig`
- `app_state_runtime_wiring.zig`
- `app_entry_runtime.zig`
- `bootstrap.zig`
- `runner.zig`
- `signals.zig`
- `update_driver.zig`

Rule:
- if the file is app-global and not specific to terminal/editor/search/tabs/config, it belongs here

### `src/app/run/`

Owns top-level run loop and frame orchestration.

Put here:
- `run_entry_runtime.zig`
- `run_entry_hooks_runtime.zig`
- `run_loop_driver.zig`
- `run_main_loop_hooks_runtime.zig`
- `run_one_frame_hooks_runtime.zig`
- `prepare_run_frame_runtime.zig`
- `draw_frame_runtime.zig`
- `frame_render_idle_runtime.zig`
- `frame_render_idle_hooks_runtime.zig`
- `update_frame_hooks_runtime.zig`
- `update_prelude_frame_runtime.zig`
- `interactive_frame.zig`
- `cursor_blink_frame.zig`
- `window_resize_event_frame.zig`

Rule:
- if the file owns app-wide frame sequencing, render/idle timing, or top-level run hooks, it belongs here

### `src/app/input/`

Owns app-level input routing and pre/post-input orchestration.

Put here:
- `input_actions_frame_runtime.zig`
- `input_actions_hooks_runtime.zig`
- `pre_input_shortcut_frame_runtime.zig`
- `pre_input_shortcut_hooks_runtime.zig`
- `post_preinput_frame.zig`
- `post_preinput_hooks_runtime.zig`
- `shortcut_action_runtime.zig`
- `mouse_pressed_frame.zig`
- `mouse_pressed_hooks_runtime.zig`
- `mouse_pressed_routing_runtime.zig`
- `pointer_activity_frame.zig`
- `reload_config_shortcut_runtime.zig`
- `mouse_debug_log.zig`

Rule:
- if the file is about host-level input gating, routing, gesture prelude, or shortcut dispatch, it belongs here

### `src/app/terminal/`

Owns terminal-specific app host/runtime glue.

Put here:
- `new_terminal_runtime.zig`
- `poll_visible_terminal_sessions_runtime.zig`
- `visible_terminal_frame.zig`
- `visible_terminal_frame_hooks_runtime.zig`
- `terminal_active_widget.zig`
- `terminal_clipboard_shortcuts.zig`
- `terminal_clipboard_shortcuts_frame.zig`
- `terminal_clipboard_shortcuts_runtime.zig`
- `terminal_close_active_runtime.zig`
- `terminal_close_confirm_actions_runtime.zig`
- `terminal_close_confirm_active_runtime.zig`
- `terminal_close_confirm_decision_runtime.zig`
- `terminal_close_confirm_draw.zig`
- `terminal_close_confirm_input.zig`
- `terminal_close_confirm_runtime.zig`
- `terminal_close_confirm_state.zig`
- `terminal_draw_surface_runtime.zig`
- `terminal_frame_pacing_runtime.zig`
- `terminal_grid.zig`
- `terminal_intent_route.zig`
- `terminal_intent_route_runtime.zig`
- `terminal_poll_runtime.zig`
- `terminal_refresh_sizing_runtime.zig`
- `terminal_resize.zig`
- `terminal_runtime_intents.zig`
- `terminal_scrollback_pager.zig`
- `terminal_session_bootstrap.zig`
- `terminal_shortcut_policy.zig`
- `terminal_shortcut_runtime.zig`
- `terminal_shortcut_suppress.zig`
- `terminal_split_resize_frame.zig`
- `terminal_surface_gate.zig`
- `terminal_tab_bar_sync.zig`
- `terminal_tab_bar_sync_runtime.zig`
- `terminal_tab_intents.zig`
- `terminal_tab_navigation_runtime.zig`
- `terminal_tab_ops.zig`
- `terminal_tabs.zig`
- `terminal_tabs_runtime.zig`
- `terminal_theme_apply.zig`
- `terminal_widget_input_hook_runtime.zig`
- `terminal_widget_input_runtime.zig`
- `terminal_workspace_route.zig`
- `deferred_terminal_resize_frame.zig`

Rule:
- if a file exists only because the app is hosting terminal sessions/widgets/workspaces, it belongs here

### `src/app/editor/`

Owns editor-specific app host/runtime glue.

Put here:
- `new_editor_runtime.zig`
- `active_editor_frame.zig`
- `editor_actions.zig`
- `editor_create_intent_runtime.zig`
- `editor_display_prepare.zig`
- `editor_draw_surface_runtime.zig`
- `editor_frame_hooks_runtime.zig`
- `editor_input_runtime.zig`
- `editor_intent_route.zig`
- `editor_seed.zig`
- `editor_shortcuts_frame.zig`
- `editor_tab_intents.zig`
- `editor_visible_caches_runtime.zig`
- `open_file_runtime.zig`
- `file_detect.zig`

Rule:
- if the file exists to host editors in the app shell, it belongs here

### `src/app/search/`

Owns search panel state and frame/runtime glue.

Put here:
- `search_panel_frame_runtime.zig`
- `search_panel_input.zig`
- `search_panel_runtime.zig`
- `search_panel_state.zig`

### `src/app/tabs/`

Owns tab bar and generic tab interaction helpers shared across views/modes.

Put here:
- `tab_action_apply.zig`
- `tab_action_apply_runtime.zig`
- `tab_action_route.zig`
- `tab_bar_width.zig`
- `tab_drag_frame.zig`
- `tab_drag_input_runtime.zig`
- `tab_drag_routing_runtime.zig`
- `tabbar_draw_runtime.zig`

Rule:
- if the file is about generic tab host behavior rather than terminal-only or editor-only behavior, it belongs here

### `src/app/config/`

Owns app-level config/theme/font reload and notices.

Put here:
- `config_reload_notice.zig`
- `config_reload_notice_state.zig`
- `font_rendering.zig`
- `font_sample_draw_runtime.zig`
- `reload_config_runtime.zig`
- `theme_utils.zig`
- `ui_layout_runtime.zig`

Rule:
- if the file is about applying or reflecting app/UI config, it belongs here

### `src/app/view/`

Owns active-view composition across terminal/editor/search.

Put here:
- `active_view_runtime.zig`
- `active_view_hooks_runtime.zig`
- `focused_entry_runtime.zig`
- `draw_overlays_runtime.zig`
- `shell_chrome_draw_runtime.zig`

Rule:
- if the file coordinates currently active content rather than owning a specific backend, it belongs here

### Keep As-Is

Keep these top-level subtrees or files where they are:
- `src/app/modes/`
- `mode_adapter_parity.zig`
- `mode_adapter_sync.zig`
- `mode_adapter_sync_runtime.zig`
- `mode_build.zig`
- `run_mode_init.zig`
- `run_mode_init_hooks_runtime.zig`

Reason:
- these are already part of the app mode-layering track and should not be mixed into the generic `src/app` reshuffle without an explicit reason

## Placement Rules

When a file could fit more than one subtree, resolve in this order:
1. backend-specific host glue (`terminal/`, `editor/`, `search/`)
2. shared interaction/chrome (`tabs/`, `input/`, `view/`)
3. app-global runtime shell (`run/`, `core/`, `config/`)

Do not create a generic `utils/` subtree.

## Migration Rules

1. Move one subtree at a time.
2. Start with `src/app/terminal/`; it has the clearest ownership and the largest pressure relief.
3. After each subtree move:
   - run import checks
   - update the owning todo/doc
   - keep follow-up rename/cleanup work separate from the move itself
4. Do not rename public functions during move-only slices unless the move itself requires it for compile correctness.

## Recommended Move Order

1. `src/app/terminal/`
2. `src/app/search/`
3. `src/app/editor/`
4. `src/app/tabs/`
5. `src/app/input/`
6. `src/app/run/`
7. `src/app/core/`
8. `src/app/config/`
9. `src/app/view/`

This order is intentionally not alphabetical. It starts with the highest-value domain split and leaves the most cross-cutting/app-global moves for later.
