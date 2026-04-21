const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const host_lifecycle_runtime = @import("../../platform/host_lifecycle_runtime.zig");
const native_host = @import("../../platform/native_host.zig");
const sdl_native_host = @import("../../platform/sdl_native_host.zig");
const platform_input_events = @import("../../platform/input_events.zig");
const input_state = @import("input_state.zig");
const iface = @import("interface.zig");
const text_input = @import("text_input.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const mouse_wheel_runtime = @import("mouse_wheel_runtime.zig");

pub fn pollInputEventsWithRuntimeWheel(domain: input_state.InputDomain) void {
    pollInputEvents(domain, mouse_wheel_runtime.deltaPtr());
}

pub fn mouseWheelMove() f32 {
    return mouse_wheel_runtime.get();
}

pub fn pollInputEvents(
    domain: input_state.InputDomain,
    mouse_wheel_delta: *f32,
) void {
    const window_log = app_logger.logger("sdl.window");
    compactInputQueue(@TypeOf(domain.key_queue.items[0]), domain.key_queue, domain.key_queue_head);
    compactInputQueue(@TypeOf(domain.char_queue.items[0]), domain.char_queue, domain.char_queue_head);
    compactInputQueue(bool, domain.focus_queue, domain.focus_queue_head);

    const state = input_state.InputState{
        .key_down = domain.key_down,
        .key_pressed = domain.key_pressed,
        .key_repeated = domain.key_repeated,
        .key_released = domain.key_released,
        .mouse_down = domain.mouse_down,
        .mouse_pressed = domain.mouse_pressed,
        .mouse_released = domain.mouse_released,
        .mouse_clicks = domain.mouse_clicks,
        .key_queue = domain.key_queue,
        .char_queue = domain.char_queue,
        .composing_text = domain.composing_text,
        .composing_cursor = domain.composing_cursor,
        .composing_selection_len = domain.composing_selection_len,
        .composing_active = domain.composing_active,
        .mouse_wheel_delta = mouse_wheel_delta,
        .window_changes = domain.window_changes,
    };
    input_state.resetForFrame(state);
    @memset(domain.mouse_press_pos_valid, false);
    input_state.resetMouseWheel(mouse_wheel_delta);

    if (domain.pending_wait_event_valid.*) {
        handleEvent(domain, domain.pending_wait_event, window_log, state);
        domain.pending_wait_event_valid.* = false;
    }

    var event: sdl_api.c.SDL_Event = undefined;
    while (sdl_api.pollEvent(&event)) {
        handleEvent(domain, &event, window_log, state);
    }

    syncWindowFocusFromFlags(domain, window_log);
    reassertFocusedTextInputBindingIfNeeded(domain, window_log);
}

fn handleEvent(
    domain: input_state.InputDomain,
    event: *const sdl_api.c.SDL_Event,
    window_log: app_logger.Logger,
    state: input_state.InputState,
) void {
    const main_window_id = sdl_api.getWindowId(domain.window);
    switch (event.type) {
        sdl_api.EVENT_QUIT => {
            domain.should_close_flag.* = true;
            domain.app_host.noteTerminationRequested();
        },
        sdl_api.EVENT_APP_WILL_ENTER_FOREGROUND => {
            host_lifecycle_runtime.onWillEnterForeground(domain.app_host);
        },
        sdl_api.EVENT_APP_DID_ENTER_FOREGROUND => {
            host_lifecycle_runtime.onDidEnterForeground(domain.app_host, domain.render_host);
        },
        sdl_api.EVENT_APP_WILL_ENTER_BACKGROUND => {
            host_lifecycle_runtime.onWillEnterBackground(domain.app_host);
        },
        sdl_api.EVENT_APP_DID_ENTER_BACKGROUND => {
            host_lifecycle_runtime.onDidEnterBackground(domain.app_host);
        },
        sdl_api.EVENT_APP_TERMINATING => {
            domain.should_close_flag.* = true;
            domain.app_host.noteTerminationRequested();
        },
        sdl_api.EVENT_DROP_FILE => {
            if (sdl_api.dropEventWindowId(event) != main_window_id) return;
            const path = sdl_api.dropEventData(event) orelse return;
            _ = domain.app_host.noteOpenFileRequested(path);
        },
        sdl_api.EVENT_WINDOW => {
            if (sdl_api.windowEventId(event) != main_window_id) return;
            handleWindowEvent(event.type, domain.app_host, domain.render_host, domain.window, domain.should_close_flag, domain.window_changes);
            if (sdl_api.isFocusGainedEvent(event.type)) {
                applyWindowFocusState(domain, window_log, true, sdl_api.windowEventName(event.type));
            }
            if (sdl_api.isFocusLostEvent(event.type)) {
                applyWindowFocusState(domain, window_log, false, sdl_api.windowEventName(event.type));
            }
        },
        sdl_api.EVENT_KEY_DOWN => {
            if (consumeGhostSuperKeyEvent(domain, event, window_log)) return;
            _ = platform_input_events.handleKeyDown(
                event,
                domain.key_down,
                domain.key_pressed,
                domain.key_repeated,
                domain.key_queue,
                domain.allocator,
            );
        },
        sdl_api.EVENT_KEY_UP => {
            if (consumeGhostSuperKeyEvent(domain, event, window_log)) return;
            _ = platform_input_events.handleKeyUp(event, domain.key_down, domain.key_released);
        },
        sdl_api.EVENT_TEXT_INPUT => {
            const text_was_composed = state.composing_active.*;
            _ = platform_input_events.handleTextInput(event, domain.char_queue, domain.allocator, text_was_composed);
            input_state.applyTextInputReset(state);
        },
        sdl_api.EVENT_TEXT_EDITING => {
            _ = platform_input_events.handleTextEditing(event, domain.composing_text, domain.composing_cursor, domain.composing_selection_len, domain.composing_active, domain.allocator);
        },
        sdl_api.EVENT_MOUSE_BUTTON_DOWN => {
            platform_input_events.handleMouseButtonDown(event, domain.mouse_down, domain.mouse_pressed, domain.mouse_clicks);
            const btn = @as(i32, @intCast(event.button.button));
            if (btn >= 0) {
                const idx: usize = @intCast(btn);
                if (idx < domain.mouse_press_pos.len) {
                    const raw_x = sdl_api.mouseButtonX(event);
                    const raw_y = sdl_api.mouseButtonY(event);
                    domain.mouse_press_pos[idx] = .{ .x = raw_x, .y = raw_y };
                    domain.mouse_press_pos_valid[idx] = true;
                }
            }
        },
        sdl_api.EVENT_MOUSE_BUTTON_UP => {
            platform_input_events.handleMouseButtonUp(event, domain.mouse_down, domain.mouse_released);
        },
        sdl_api.EVENT_MOUSE_WHEEL => input_state.addMouseWheel(state.mouse_wheel_delta, platform_input_events.wheelDelta(event)),
        else => {
            if (sdl_api.isRuntimeWakeEvent(event.type)) return;
            if (sdl_api.isWindowEventType(event.type)) {
                if (sdl_api.windowEventId(event) != main_window_id) return;
                handleWindowEvent(event.type, domain.app_host, domain.render_host, domain.window, domain.should_close_flag, domain.window_changes);
                if (sdl_api.isFocusGainedEvent(event.type)) {
                    applyWindowFocusState(domain, window_log, true, sdl_api.windowEventName(event.type));
                }
                if (sdl_api.isFocusLostEvent(event.type)) {
                    applyWindowFocusState(domain, window_log, false, sdl_api.windowEventName(event.type));
                }
            }
        },
    }
}

fn syncWindowFocusFromFlags(
    domain: input_state.InputDomain,
    window_log: app_logger.Logger,
) void {
    const focused = sdl_api.windowHasInputFocus(domain.window);
    if (focused == domain.window_focused.*) return;
    applyWindowFocusState(domain, window_log, focused, "window_flags");
}

fn shouldReassertTextInputBindingForWindowChanges(changes: sdl_api.WindowChangeMask) bool {
    return changes.moved or changes.affectsWindowRefresh();
}

fn shouldResetKeyboardStateForWindowChanges(changes: sdl_api.WindowChangeMask) bool {
    return changes.moved or changes.display_changed or changes.display_scale_changed;
}

fn isSuperScancode(scancode: i32) bool {
    return scancode == @as(i32, @intCast(sdl_api.c.SDL_SCANCODE_LGUI)) or
        scancode == @as(i32, @intCast(sdl_api.c.SDL_SCANCODE_RGUI));
}

fn advanceGhostSuperQuarantine(
    suppress_super_until_release: *bool,
    event_type: c_uint,
    scancode: i32,
) bool {
    if (!suppress_super_until_release.*) return false;
    if (isSuperScancode(scancode)) {
        if (event_type == sdl_api.EVENT_KEY_UP) {
            suppress_super_until_release.* = false;
        }
        return true;
    }
    if (event_type == sdl_api.EVENT_KEY_DOWN) {
        suppress_super_until_release.* = false;
    }
    return false;
}

fn consumeGhostSuperKeyEvent(
    domain: input_state.InputDomain,
    event: *const sdl_api.c.SDL_Event,
    window_log: app_logger.Logger,
) bool {
    const scancode = sdl_api.keyScancode(event);
    const was_quarantined = domain.suppress_super_until_release.*;
    const consumed = advanceGhostSuperQuarantine(
        domain.suppress_super_until_release,
        event.type,
        scancode,
    );
    if (consumed) {
        window_log.logf(.info, "ghost super suppressed action={s} scancode={d}", .{
            if (event.type == sdl_api.EVENT_KEY_DOWN) "press" else "release",
            scancode,
        });
        return true;
    }
    if (was_quarantined and !domain.suppress_super_until_release.* and event.type == sdl_api.EVENT_KEY_DOWN) {
        window_log.logf(.info, "ghost super quarantine cleared reason=non_super_key scancode={d}", .{
            scancode,
        });
    }
    return false;
}

fn reassertFocusedTextInputBindingIfNeeded(
    domain: input_state.InputDomain,
    window_log: app_logger.Logger,
) void {
    if (!domain.window_focused.*) return;
    if (!shouldReassertTextInputBindingForWindowChanges(domain.window_changes.*)) return;

    if (shouldResetKeyboardStateForWindowChanges(domain.window_changes.*)) {
        resetKeyboardStateForFocusTransition(domain);
        resetSdlKeyboardState();
        window_log.logf(.info, "keyboard state reset reason=window_change moved={d} display={d} display_scale={d}", .{
            @intFromBool(domain.window_changes.moved),
            @intFromBool(domain.window_changes.display_changed),
            @intFromBool(domain.window_changes.display_scale_changed),
        });
    }
    sdl_api.startTextInput(domain.window);
    text_input.reapplyRect(domain.text_input_state, domain.window);
    window_log.logf(.info, "text input reasserted reason=window_change moved={d} resized={d} pixel_size={d} display={d} display_scale={d} exposed={d}", .{
        @intFromBool(domain.window_changes.moved),
        @intFromBool(domain.window_changes.resized),
        @intFromBool(domain.window_changes.pixel_size_changed),
        @intFromBool(domain.window_changes.display_changed),
        @intFromBool(domain.window_changes.display_scale_changed),
        @intFromBool(domain.window_changes.contents_exposed),
    });
}

fn applyWindowFocusState(
    domain: input_state.InputDomain,
    window_log: app_logger.Logger,
    focused: bool,
    source: []const u8,
) void {
    if (domain.window_focused.* == focused) return;

    resetKeyboardStateForFocusTransition(domain);
    resetSdlKeyboardState();
    if (focused) {
        sdl_api.startTextInput(domain.window);
        text_input.reapplyRect(domain.text_input_state, domain.window);
        host_lifecycle_runtime.onWindowFocusChanged(domain.app_host, true);
    } else {
        sdl_api.stopTextInput(domain.window);
        host_lifecycle_runtime.onWindowFocusChanged(domain.app_host, false);
    }
    domain.window_focused.* = focused;
    window_log.logf(.info, "window focus source={s} focused={d}", .{
        source,
        @intFromBool(focused),
    });
    domain.focus_queue.append(domain.allocator, focused) catch |err| {
        window_log.logf(.warning, "focus queue append failed focused={d} err={s}", .{
            @intFromBool(focused),
            @errorName(err),
        });
    };
}

fn resetKeyboardStateForFocusTransition(domain: input_state.InputDomain) void {
    @memset(domain.key_down, false);
    @memset(domain.key_pressed, false);
    @memset(domain.key_repeated, false);
    @memset(domain.key_released, false);
    domain.key_queue.clearRetainingCapacity();
    domain.key_queue_head.* = 0;
    domain.suppress_super_until_release.* = true;
}

fn resetSdlKeyboardState() void {
    sdl_api.resetKeyboard();
    sdl_api.clearModState();
}

fn handleWindowEvent(
    event_type: c_uint,
    app_host: *native_host.PlatformAppHost,
    render_host: *native_host.PlatformRenderHost,
    window: *sdl_api.c.SDL_Window,
    should_close: *bool,
    window_changes: *sdl_api.WindowChangeMask,
) void {
    const change = sdl_api.classifyWindowChange(event_type);
    if (change.any()) {
        window_changes.merge(change);
        if (change.affectsWindowRefresh()) {
            if (!host_lifecycle_runtime.onWindowRefresh(app_host, render_host, window)) {
                render_host.noteSurfaceAvailable(sdl_native_host.captureWindowSurfaceMetrics(window));
                render_host.noteRedrawRequested();
            }
        }
    }
    if (sdl_api.isCloseEvent(event_type)) {
        should_close.* = true;
        app_host.noteTerminationRequested();
    }
}

fn compactInputQueue(comptime T: type, queue: *std.ArrayList(T), head: *usize) void {
    if (head.* == 0) return;
    if (head.* >= queue.items.len) {
        queue.clearRetainingCapacity();
        head.* = 0;
        return;
    }
    const remaining = queue.items.len - head.*;
    std.mem.copyForwards(T, queue.items[0..remaining], queue.items[head.*..queue.items.len]);
    queue.items.len = remaining;
    head.* = 0;
}

test "text input binding reasserts for moved or refreshed focused windows" {
    try std.testing.expect(!shouldReassertTextInputBindingForWindowChanges(.{}));
    try std.testing.expect(shouldReassertTextInputBindingForWindowChanges(.{ .moved = true }));
    try std.testing.expect(shouldReassertTextInputBindingForWindowChanges(.{ .resized = true }));
    try std.testing.expect(shouldReassertTextInputBindingForWindowChanges(.{ .display_changed = true }));
    try std.testing.expect(shouldReassertTextInputBindingForWindowChanges(.{ .contents_exposed = true }));
}

test "keyboard state reset is limited to move and display transitions" {
    try std.testing.expect(!shouldResetKeyboardStateForWindowChanges(.{}));
    try std.testing.expect(shouldResetKeyboardStateForWindowChanges(.{ .moved = true }));
    try std.testing.expect(shouldResetKeyboardStateForWindowChanges(.{ .display_changed = true }));
    try std.testing.expect(shouldResetKeyboardStateForWindowChanges(.{ .display_scale_changed = true }));
    try std.testing.expect(!shouldResetKeyboardStateForWindowChanges(.{ .resized = true }));
    try std.testing.expect(!shouldResetKeyboardStateForWindowChanges(.{ .pixel_size_changed = true }));
}

test "ghost super quarantine suppresses super until release or normal keydown" {
    var suppress_super_until_release = true;

    try std.testing.expect(advanceGhostSuperQuarantine(
        &suppress_super_until_release,
        sdl_api.EVENT_KEY_DOWN,
        @intCast(sdl_api.c.SDL_SCANCODE_LGUI),
    ));
    try std.testing.expect(suppress_super_until_release);

    try std.testing.expect(!advanceGhostSuperQuarantine(
        &suppress_super_until_release,
        sdl_api.EVENT_KEY_DOWN,
        @intCast(sdl_api.c.SDL_SCANCODE_A),
    ));
    try std.testing.expect(!suppress_super_until_release);

    suppress_super_until_release = true;
    try std.testing.expect(advanceGhostSuperQuarantine(
        &suppress_super_until_release,
        sdl_api.EVENT_KEY_UP,
        @intCast(sdl_api.c.SDL_SCANCODE_RGUI),
    ));
    try std.testing.expect(!suppress_super_until_release);
}

test "keyboard state resets across focus transitions" {
    var key_down = [_]bool{ true, true, false };
    var key_pressed = [_]bool{ true, false, false };
    var key_repeated = [_]bool{ false, true, false };
    var key_released = [_]bool{ false, false, true };
    var key_queue = std.ArrayList(input_state.KeyPress).empty;
    defer key_queue.deinit(std.testing.allocator);
    try key_queue.append(std.testing.allocator, .{
        .scancode = 1,
        .sym = 1,
        .mod_bits = 0,
        .repeated = false,
    });
    var key_queue_head: usize = 0;

    var should_close = false;
    var mouse_down = [_]bool{false} ** 1;
    var mouse_pressed = [_]bool{false} ** 1;
    var mouse_released = [_]bool{false} ** 1;
    var mouse_clicks = [_]u8{0} ** 1;
    var mouse_press_pos = [_]iface.MousePos{.{ .x = 0, .y = 0 }} ** 1;
    var mouse_press_pos_valid = [_]bool{false} ** 1;
    var char_queue = std.ArrayList(input_state.TextPress).empty;
    defer char_queue.deinit(std.testing.allocator);
    var char_queue_head: usize = 0;
    var focus_queue = std.ArrayList(bool).empty;
    defer focus_queue.deinit(std.testing.allocator);
    var focus_queue_head: usize = 0;
    var window_focused = true;
    var suppress_super_until_release = false;
    var composing_text = std.ArrayList(u8).empty;
    defer composing_text.deinit(std.testing.allocator);
    var composing_cursor: i32 = 0;
    var composing_selection_len: i32 = 0;
    var composing_active = false;
    var window_changes: sdl_api.WindowChangeMask = .{};
    var text_input_state = text_input.initState();
    var pending_wait_event: sdl_api.c.SDL_Event = undefined;
    var pending_wait_event_valid = false;
    var app_host = native_host.currentAppHost();
    var render_host = native_host.PlatformRenderHost{
        .binding = .none,
        .surface_availability = .available,
        .surface_metrics = .{},
        .native_handles = .{},
    };

    const domain: input_state.InputDomain = .{
        .allocator = std.testing.allocator,
        .app_host = &app_host,
        .render_host = &render_host,
        .window = undefined,
        .should_close_flag = &should_close,
        .key_down = key_down[0..],
        .key_pressed = key_pressed[0..],
        .key_repeated = key_repeated[0..],
        .key_released = key_released[0..],
        .mouse_down = mouse_down[0..],
        .mouse_pressed = mouse_pressed[0..],
        .mouse_released = mouse_released[0..],
        .mouse_clicks = mouse_clicks[0..],
        .mouse_press_pos = mouse_press_pos[0..],
        .mouse_press_pos_valid = mouse_press_pos_valid[0..],
        .key_queue = &key_queue,
        .key_queue_head = &key_queue_head,
        .char_queue = &char_queue,
        .char_queue_head = &char_queue_head,
        .focus_queue = &focus_queue,
        .focus_queue_head = &focus_queue_head,
        .window_focused = &window_focused,
        .suppress_super_until_release = &suppress_super_until_release,
        .composing_text = &composing_text,
        .composing_cursor = &composing_cursor,
        .composing_selection_len = &composing_selection_len,
        .composing_active = &composing_active,
        .window_changes = &window_changes,
        .text_input_state = &text_input_state,
        .pending_wait_event = &pending_wait_event,
        .pending_wait_event_valid = &pending_wait_event_valid,
    };

    resetKeyboardStateForFocusTransition(domain);
    try std.testing.expectEqualSlices(bool, &[_]bool{ false, false, false }, key_down[0..]);
    try std.testing.expectEqualSlices(bool, &[_]bool{ false, false, false }, key_pressed[0..]);
    try std.testing.expectEqualSlices(bool, &[_]bool{ false, false, false }, key_repeated[0..]);
    try std.testing.expectEqualSlices(bool, &[_]bool{ false, false, false }, key_released[0..]);
    try std.testing.expectEqual(@as(usize, 0), key_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), key_queue_head);
    try std.testing.expect(suppress_super_until_release);
}
