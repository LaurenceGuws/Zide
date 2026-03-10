const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const platform_input_events = @import("../../platform/input_events.zig");
const input_state = @import("input_state.zig");
const text_input = @import("text_input.zig");
const input_logging = @import("input_logging.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

pub fn pollInputEvents(
    self: anytype,
    mouse_wheel_delta: *f32,
    sdl_input_env_logged: *bool,
    sdl3_textinput_layout_logged: *bool,
    sdl3_textediting_layout_logged: *bool,
) void {
    const input_log = app_logger.logger("input.sdl");
    const window_log = app_logger.logger("sdl.window");
    if (!sdl_input_env_logged.*) {
        input_log.logf(
            .info,
            "sdl build_version=sdl3 event_size={d}",
            .{sdl_api.sdlEventSize()},
        );
        sdl_input_env_logged.* = true;
    }
    compactInputQueue(@TypeOf(self.key_queue.items[0]), &self.key_queue, &self.key_queue_head);
    compactInputQueue(@TypeOf(self.char_queue.items[0]), &self.char_queue, &self.char_queue_head);
    compactInputQueue(bool, &self.focus_queue, &self.focus_queue_head);

    const state = input_state.InputState{
        .key_down = self.key_down[0..],
        .key_pressed = self.key_pressed[0..],
        .key_repeated = self.key_repeated[0..],
        .key_released = self.key_released[0..],
        .mouse_down = self.mouse_down[0..],
        .mouse_pressed = self.mouse_pressed[0..],
        .mouse_released = self.mouse_released[0..],
        .mouse_clicks = self.mouse_clicks[0..],
        .key_queue = &self.key_queue,
        .char_queue = &self.char_queue,
        .composing_text = &self.composing_text,
        .composing_cursor = &self.composing_cursor,
        .composing_selection_len = &self.composing_selection_len,
        .composing_active = &self.composing_active,
        .mouse_wheel_delta = mouse_wheel_delta,
        .window_resized_flag = &self.window_resized_flag,
    };
    input_state.resetForFrame(state);
    @memset(self.mouse_press_pos_valid[0..], false);
    input_state.resetMouseWheel(mouse_wheel_delta);

    var event: sdl_api.c.SDL_Event = undefined;
    var event_count: usize = 0;
    while (sdl_api.pollEvent(&event)) {
        event_count += 1;
        handleEvent(self, &event, input_log, window_log, state, sdl3_textinput_layout_logged, sdl3_textediting_layout_logged);
    }
    if (event_count > 0) input_log.logf(.info, "sdl3 polled events={d}", .{event_count});
}

fn handleEvent(
    self: anytype,
    event: *const sdl_api.c.SDL_Event,
    input_log: app_logger.Logger,
    window_log: app_logger.Logger,
    state: input_state.InputState,
    sdl3_textinput_layout_logged: *bool,
    sdl3_textediting_layout_logged: *bool,
) void {
    switch (event.type) {
        sdl_api.EVENT_QUIT => self.should_close_flag = true,
        sdl_api.EVENT_WINDOW => {
            handleWindowEvent(event.type, &self.should_close_flag, &self.window_resized_flag);
            if (sdl_api.isFocusGainedEvent(event.type)) {
                sdl_api.startTextInput(self.window);
                text_input.reapplyRect(&self.text_input_state, self.window);
                self.focus_queue.append(self.allocator, true) catch |err| {
                    window_log.logf(.warning, "focus queue append failed focused=1 err={s}", .{@errorName(err)});
                };
            }
            if (sdl_api.isFocusLostEvent(event.type)) {
                sdl_api.stopTextInput(self.window);
                sdl_api.setEventEnabled(sdl_api.EVENT_MOUSE_MOTION, false);
                self.focus_queue.append(self.allocator, false) catch |err| {
                    window_log.logf(.warning, "focus queue append failed focused=0 err={s}", .{@errorName(err)});
                };
            }
            window_log.logf(.info, "event={s} data1={d} data2={d}", .{
                sdl_api.windowEventName(event.type),
                sdl_api.windowEventData1(event),
                sdl_api.windowEventData2(event),
            });
        },
        sdl_api.EVENT_KEY_DOWN => {
            const key_info = platform_input_events.handleKeyDown(
                event,
                self.key_down[0..],
                self.key_pressed[0..],
                self.key_repeated[0..],
                &self.key_queue,
                self.allocator,
            );
            input_log.logf(.info, "keydown sc={d} sym={d} repeat={d}", .{ key_info.scancode, key_info.sym, key_info.repeat });
        },
        sdl_api.EVENT_KEY_UP => {
            const key_info = platform_input_events.handleKeyUp(event, self.key_down[0..], self.key_released[0..]);
            input_log.logf(.info, "keyup sc={d} sym={d}", .{ key_info.scancode, key_info.sym });
        },
        sdl_api.EVENT_TEXT_INPUT => {
            const text_was_composed = state.composing_active.*;
            const text_len = platform_input_events.handleTextInput(event, &self.char_queue, self.allocator, text_was_composed);
            input_state.applyTextInputReset(state);
            input_logging.logTextInput(text_len);
            input_log.logf(.info, "textinput type={d}", .{event.type});
            if (!sdl3_textinput_layout_logged.*) {
                const layout = sdl_api.textInputLayout();
                input_logging.logTextInputLayout(layout.size, sdl_api.sdlEventSize(), layout.offset_type, layout.offset_reserved, layout.offset_timestamp, layout.offset_window_id, layout.offset_text);
                input_logging.logEventBytes("textinput event", std.mem.asBytes(event));
                sdl3_textinput_layout_logged.* = true;
            }
            input_logging.logTextInputPointer(text_len, sdl_api.textInputPointer(event));
            if (text_len > 0) {
                const text = sdl_api.textSpanWithLen(event.text.text, text_len);
                input_logging.logTextInputRaw(text);
            }
        },
        sdl_api.EVENT_TEXT_EDITING => {
            const edit_info = platform_input_events.handleTextEditing(event, &self.composing_text, &self.composing_cursor, &self.composing_selection_len, &self.composing_active, self.allocator);
            input_logging.logTextEditing(edit_info.bytes, edit_info.cursor, edit_info.selection_len);
            if (!sdl3_textediting_layout_logged.*) {
                const layout = sdl_api.textEditingLayout();
                input_logging.logTextEditingLayout(layout.size, sdl_api.sdlEventSize(), layout.offset_type, layout.offset_reserved, layout.offset_timestamp, layout.offset_window_id, layout.offset_text, layout.offset_start, layout.offset_length, layout.offset_cursor, layout.offset_selection_len);
                input_logging.logEventBytes("textedit event", std.mem.asBytes(event));
                sdl3_textediting_layout_logged.* = true;
            }
            input_logging.logTextEditingPointer(edit_info.bytes, edit_info.cursor, edit_info.selection_len, sdl_api.textEditingPointer(event));
            if (edit_info.bytes > 0) {
                const text = sdl_api.textSpanWithLen(event.edit.text, edit_info.bytes);
                input_logging.logTextEditingRaw(text, edit_info.cursor, edit_info.selection_len);
            }
        },
        sdl_api.EVENT_MOUSE_BUTTON_DOWN => {
            platform_input_events.handleMouseButtonDown(event, self.mouse_down[0..], self.mouse_pressed[0..], self.mouse_clicks[0..]);
            const btn = @as(i32, @intCast(event.button.button));
            if (btn >= 0) {
                const idx: usize = @intCast(btn);
                if (idx < self.mouse_press_pos.len) {
                    const raw_x = sdl_api.mouseButtonX(event);
                    const raw_y = sdl_api.mouseButtonY(event);
                    self.mouse_press_pos[idx] = .{ .x = raw_x * self.mouse_scale.x, .y = raw_y * self.mouse_scale.y };
                    self.mouse_press_pos_valid[idx] = true;
                }
            }
            sdl_api.setEventEnabled(sdl_api.EVENT_MOUSE_MOTION, true);
        },
        sdl_api.EVENT_MOUSE_BUTTON_UP => {
            platform_input_events.handleMouseButtonUp(event, self.mouse_down[0..], self.mouse_released[0..]);
            if (!self.anyMouseButtonsDown()) sdl_api.setEventEnabled(sdl_api.EVENT_MOUSE_MOTION, false);
        },
        sdl_api.EVENT_MOUSE_WHEEL => input_state.addMouseWheel(state.mouse_wheel_delta, platform_input_events.wheelDelta(event)),
        else => {
            if (sdl_api.isWindowEventType(event.type)) {
                handleWindowEvent(event.type, &self.should_close_flag, &self.window_resized_flag);
                if (sdl_api.isFocusGainedEvent(event.type)) {
                    sdl_api.startTextInput(self.window);
                    text_input.reapplyRect(&self.text_input_state, self.window);
                    self.focus_queue.append(self.allocator, true) catch |err| {
                        window_log.logf(.warning, "focus queue append failed focused=1 err={s}", .{@errorName(err)});
                    };
                }
                if (sdl_api.isFocusLostEvent(event.type)) {
                    sdl_api.stopTextInput(self.window);
                    sdl_api.setEventEnabled(sdl_api.EVENT_MOUSE_MOTION, false);
                    self.focus_queue.append(self.allocator, false) catch |err| {
                        window_log.logf(.warning, "focus queue append failed focused=0 err={s}", .{@errorName(err)});
                    };
                }
                window_log.logf(.info, "event={s} data1={d} data2={d}", .{
                    sdl_api.windowEventName(event.type),
                    sdl_api.windowEventData1(event),
                    sdl_api.windowEventData2(event),
                });
            }
        },
    }
}

fn handleWindowEvent(event_type: c_uint, should_close: *bool, window_resized: *bool) void {
    if (sdl_api.isResizeEvent(event_type)) {
        window_resized.* = true;
        return;
    }
    if (sdl_api.isCloseEvent(event_type)) {
        should_close.* = true;
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
