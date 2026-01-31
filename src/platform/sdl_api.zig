const std = @import("std");
const build_options = @import("build_options");

pub const is_sdl3 = std.mem.eql(u8, build_options.sdl_version, "sdl3");

pub const c = @cImport({
    if (is_sdl3) {
        @cInclude("SDL3/SDL.h");
        @cInclude("SDL3/SDL_opengl.h");
    } else {
        @cInclude("SDL2/SDL.h");
        @cInclude("SDL2/SDL_opengl.h");
    }
});

pub const EVENT_QUIT: c_uint = if (is_sdl3) c.SDL_EVENT_QUIT else c.SDL_QUIT;
pub const EVENT_WINDOW: c_uint = if (is_sdl3)
    if (@hasDecl(c, "SDL_EVENT_WINDOW")) c.SDL_EVENT_WINDOW else c.SDL_EVENT_WINDOW_SHOWN
else
    c.SDL_WINDOWEVENT;
pub const EVENT_KEY_DOWN: c_uint = if (is_sdl3) c.SDL_EVENT_KEY_DOWN else c.SDL_KEYDOWN;
pub const EVENT_KEY_UP: c_uint = if (is_sdl3) c.SDL_EVENT_KEY_UP else c.SDL_KEYUP;
pub const EVENT_TEXT_INPUT: c_uint = if (is_sdl3) c.SDL_EVENT_TEXT_INPUT else c.SDL_TEXTINPUT;
pub const EVENT_TEXT_EDITING: c_uint = if (is_sdl3) c.SDL_EVENT_TEXT_EDITING else c.SDL_TEXTEDITING;
pub const EVENT_MOUSE_BUTTON_DOWN: c_uint = if (is_sdl3) c.SDL_EVENT_MOUSE_BUTTON_DOWN else c.SDL_MOUSEBUTTONDOWN;
pub const EVENT_MOUSE_BUTTON_UP: c_uint = if (is_sdl3) c.SDL_EVENT_MOUSE_BUTTON_UP else c.SDL_MOUSEBUTTONUP;
pub const EVENT_MOUSE_WHEEL: c_uint = if (is_sdl3) c.SDL_EVENT_MOUSE_WHEEL else c.SDL_MOUSEWHEEL;

pub const TextInputLayout = struct {
    size: usize,
    offset_type: ?usize,
    offset_reserved: ?usize,
    offset_timestamp: ?usize,
    offset_window_id: ?usize,
    offset_text: ?usize,
};

pub const TextEditingLayout = struct {
    size: usize,
    offset_type: ?usize,
    offset_reserved: ?usize,
    offset_timestamp: ?usize,
    offset_window_id: ?usize,
    offset_text: ?usize,
    offset_start: ?usize,
    offset_length: ?usize,
    offset_cursor: ?usize,
    offset_selection_len: ?usize,
};

pub fn textInputLayout() TextInputLayout {
    return .{
        .size = @sizeOf(c.SDL_TextInputEvent),
        .offset_type = fieldOffset(c.SDL_TextInputEvent, "type"),
        .offset_reserved = fieldOffset(c.SDL_TextInputEvent, "reserved"),
        .offset_timestamp = fieldOffset(c.SDL_TextInputEvent, "timestamp"),
        .offset_window_id = fieldOffset(c.SDL_TextInputEvent, "windowID"),
        .offset_text = fieldOffset(c.SDL_TextInputEvent, "text"),
    };
}

pub fn textEditingLayout() TextEditingLayout {
    return .{
        .size = @sizeOf(c.SDL_TextEditingEvent),
        .offset_type = fieldOffset(c.SDL_TextEditingEvent, "type"),
        .offset_reserved = fieldOffset(c.SDL_TextEditingEvent, "reserved"),
        .offset_timestamp = fieldOffset(c.SDL_TextEditingEvent, "timestamp"),
        .offset_window_id = fieldOffset(c.SDL_TextEditingEvent, "windowID"),
        .offset_text = fieldOffset(c.SDL_TextEditingEvent, "text"),
        .offset_start = fieldOffset(c.SDL_TextEditingEvent, "start"),
        .offset_length = fieldOffset(c.SDL_TextEditingEvent, "length"),
        .offset_cursor = fieldOffset(c.SDL_TextEditingEvent, "cursor"),
        .offset_selection_len = fieldOffset(c.SDL_TextEditingEvent, "selection_len"),
    };
}

pub fn isWindowEventType(event_type: c_uint) bool {
    if (is_sdl3) {
        if (@hasDecl(c, "SDL_EVENT_WINDOW_SHOWN") and event_type == c.SDL_EVENT_WINDOW_SHOWN) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_HIDDEN") and event_type == c.SDL_EVENT_WINDOW_HIDDEN) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_EXPOSED") and event_type == c.SDL_EVENT_WINDOW_EXPOSED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MOVED") and event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_RESIZED") and event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_SIZE_CHANGED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MINIMIZED") and event_type == c.SDL_EVENT_WINDOW_MINIMIZED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MAXIMIZED") and event_type == c.SDL_EVENT_WINDOW_MAXIMIZED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_RESTORED") and event_type == c.SDL_EVENT_WINDOW_RESTORED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_ENTER") and event_type == c.SDL_EVENT_WINDOW_ENTER) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_LEAVE") and event_type == c.SDL_EVENT_WINDOW_LEAVE) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_GAINED") and event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_LOST") and event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_CLOSE_REQUESTED") and event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_TAKE_FOCUS") and event_type == c.SDL_EVENT_WINDOW_TAKE_FOCUS) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_HIT_TEST") and event_type == c.SDL_EVENT_WINDOW_HIT_TEST) return true;
        return false;
    }
    return event_type == c.SDL_WINDOWEVENT;
}

pub fn windowEventName(event_type: c_uint, window_event_id: u8) []const u8 {
    if (is_sdl3) {
        if (@hasDecl(c, "SDL_EVENT_WINDOW_SHOWN") and event_type == c.SDL_EVENT_WINDOW_SHOWN) return "shown";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_HIDDEN") and event_type == c.SDL_EVENT_WINDOW_HIDDEN) return "hidden";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_EXPOSED") and event_type == c.SDL_EVENT_WINDOW_EXPOSED) return "exposed";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MOVED") and event_type == c.SDL_EVENT_WINDOW_MOVED) return "moved";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_RESIZED") and event_type == c.SDL_EVENT_WINDOW_RESIZED) return "resized";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return "size_changed";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_SIZE_CHANGED) return "size_changed";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MINIMIZED") and event_type == c.SDL_EVENT_WINDOW_MINIMIZED) return "minimized";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MAXIMIZED") and event_type == c.SDL_EVENT_WINDOW_MAXIMIZED) return "maximized";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_RESTORED") and event_type == c.SDL_EVENT_WINDOW_RESTORED) return "restored";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_ENTER") and event_type == c.SDL_EVENT_WINDOW_ENTER) return "enter";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_LEAVE") and event_type == c.SDL_EVENT_WINDOW_LEAVE) return "leave";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_GAINED") and event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED) return "focus_gained";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_LOST") and event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST) return "focus_lost";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_CLOSE_REQUESTED") and event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) return "close";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_TAKE_FOCUS") and event_type == c.SDL_EVENT_WINDOW_TAKE_FOCUS) return "take_focus";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_HIT_TEST") and event_type == c.SDL_EVENT_WINDOW_HIT_TEST) return "hit_test";
        if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return "display_changed";
        return "unknown";
    }
    return switch (window_event_id) {
        c.SDL_WINDOWEVENT_SHOWN => "shown",
        c.SDL_WINDOWEVENT_HIDDEN => "hidden",
        c.SDL_WINDOWEVENT_EXPOSED => "exposed",
        c.SDL_WINDOWEVENT_MOVED => "moved",
        c.SDL_WINDOWEVENT_RESIZED => "resized",
        c.SDL_WINDOWEVENT_SIZE_CHANGED => "size_changed",
        c.SDL_WINDOWEVENT_MINIMIZED => "minimized",
        c.SDL_WINDOWEVENT_MAXIMIZED => "maximized",
        c.SDL_WINDOWEVENT_RESTORED => "restored",
        c.SDL_WINDOWEVENT_ENTER => "enter",
        c.SDL_WINDOWEVENT_LEAVE => "leave",
        c.SDL_WINDOWEVENT_FOCUS_GAINED => "focus_gained",
        c.SDL_WINDOWEVENT_FOCUS_LOST => "focus_lost",
        c.SDL_WINDOWEVENT_CLOSE => "close",
        c.SDL_WINDOWEVENT_TAKE_FOCUS => "take_focus",
        c.SDL_WINDOWEVENT_HIT_TEST => "hit_test",
        c.SDL_WINDOWEVENT_DISPLAY_CHANGED => "display_changed",
        else => "unknown",
    };
}

pub fn isResizeEvent(event_type: c_uint, window_event_id: u8) bool {
    if (is_sdl3) {
        if (@hasDecl(c, "SDL_EVENT_WINDOW_RESIZED") and event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_SIZE_CHANGED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_MOVED") and event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
        if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
        return false;
    }
    return window_event_id == c.SDL_WINDOWEVENT_RESIZED or
        window_event_id == c.SDL_WINDOWEVENT_SIZE_CHANGED or
        window_event_id == c.SDL_WINDOWEVENT_MOVED or
        window_event_id == c.SDL_WINDOWEVENT_DISPLAY_CHANGED;
}

pub fn isCloseEvent(event_type: c_uint, window_event_id: u8) bool {
    if (is_sdl3) {
        return @hasDecl(c, "SDL_EVENT_WINDOW_CLOSE_REQUESTED") and event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
    }
    return window_event_id == c.SDL_WINDOWEVENT_CLOSE;
}

pub fn isFocusGainedEvent(event_type: c_uint, window_event_id: u8) bool {
    if (is_sdl3) {
        return @hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_GAINED") and event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED;
    }
    return window_event_id == c.SDL_WINDOWEVENT_FOCUS_GAINED;
}

pub fn isFocusLostEvent(event_type: c_uint, window_event_id: u8) bool {
    if (is_sdl3) {
        return @hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_LOST") and event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST;
    }
    return window_event_id == c.SDL_WINDOWEVENT_FOCUS_LOST;
}

pub fn windowEventData1(event: *const c.SDL_Event) i32 {
    const win = event.window;
    if (@hasField(@TypeOf(win), "data1")) return @intCast(win.data1);
    return 0;
}

pub fn windowEventData2(event: *const c.SDL_Event) i32 {
    const win = event.window;
    if (@hasField(@TypeOf(win), "data2")) return @intCast(win.data2);
    return 0;
}

pub fn setHint(name: [*:0]const u8, value: [*:0]const u8) void {
    _ = c.SDL_SetHint(name, value);
}

pub fn init(flags: c_uint) bool {
    if (is_sdl3) {
        return c.SDL_Init(flags);
    }
    return c.SDL_Init(flags) == 0;
}

pub fn defaultInitFlags() c_uint {
    if (is_sdl3) {
        return @intCast(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS);
    }
    return @intCast(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER);
}

pub fn quit() void {
    c.SDL_Quit();
}

pub const GlAttr = if (is_sdl3) c.SDL_GLAttr else c.SDL_GLattr;

pub fn glSetAttribute(attr: GlAttr, value: c_int) void {
    _ = c.SDL_GL_SetAttribute(attr, value);
}

pub fn createWindow(title: [*:0]const u8, width: c_int, height: c_int) ?*c.SDL_Window {
    const high_dpi = if (@hasDecl(c, "SDL_WINDOW_HIGH_PIXEL_DENSITY"))
        @as(c_uint, @intCast(c.SDL_WINDOW_HIGH_PIXEL_DENSITY))
    else if (@hasDecl(c, "SDL_WINDOW_ALLOW_HIGHDPI"))
        @as(c_uint, @intCast(c.SDL_WINDOW_ALLOW_HIGHDPI))
    else
        0;
    const base_flags: c_uint = @intCast(c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
    const flags: c_uint = base_flags | high_dpi;
    if (is_sdl3) {
        return c.SDL_CreateWindow(title, width, height, flags);
    }
    return c.SDL_CreateWindow(
        title,
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        width,
        height,
        flags,
    );
}

pub fn destroyWindow(window: *c.SDL_Window) void {
    c.SDL_DestroyWindow(window);
}

pub fn glCreateContext(window: *c.SDL_Window) ?c.SDL_GLContext {
    return c.SDL_GL_CreateContext(window);
}

pub fn glDeleteContext(context: c.SDL_GLContext) void {
    if (@hasDecl(c, "SDL_GL_DestroyContext")) {
        _ = c.SDL_GL_DestroyContext(context);
    } else {
        c.SDL_GL_DeleteContext(context);
    }
}

pub fn getWindowSize(window: *c.SDL_Window, w: *c_int, h: *c_int) void {
    if (is_sdl3) {
        _ = c.SDL_GetWindowSize(window, w, h);
    } else {
        c.SDL_GetWindowSize(window, w, h);
    }
}

pub fn getDrawableSize(window: *c.SDL_Window, w: *c_int, h: *c_int) void {
    if (@hasDecl(c, "SDL_GL_GetDrawableSize")) {
        c.SDL_GL_GetDrawableSize(window, w, h);
    } else if (@hasDecl(c, "SDL_GetWindowSizeInPixels")) {
        _ = c.SDL_GetWindowSizeInPixels(window, w, h);
    } else {
        getWindowSize(window, w, h);
    }
}

pub fn getWindowDisplayIndex(window: *c.SDL_Window) i32 {
    if (@hasDecl(c, "SDL_GetDisplayForWindow")) {
        return @intCast(c.SDL_GetDisplayForWindow(window));
    }
    return c.SDL_GetWindowDisplayIndex(window);
}

pub fn getWindowDisplayScale(window: *c.SDL_Window) f32 {
    if (@hasDecl(c, "SDL_GetWindowDisplayScale")) {
        return c.SDL_GetWindowDisplayScale(window);
    }
    return 0.0;
}

pub fn getWindowPixelDensity(window: *c.SDL_Window) f32 {
    if (@hasDecl(c, "SDL_GetWindowPixelDensity")) {
        return c.SDL_GetWindowPixelDensity(window);
    }
    return 0.0;
}

pub fn getDisplayBounds(display: i32, rect: *c.SDL_Rect) bool {
    if (@hasDecl(c, "SDL_GetDisplayBounds")) {
        if (is_sdl3) {
            return c.SDL_GetDisplayBounds(@intCast(display), rect);
        }
        return c.SDL_GetDisplayBounds(display, rect) == 0;
    }
    return false;
}

pub fn getDisplayDpi(display: i32, ddpi: *f32, hdpi: *f32, vdpi: *f32) bool {
    if (@hasDecl(c, "SDL_GetDisplayDPI")) {
        if (is_sdl3) {
            return c.SDL_GetDisplayDPI(@intCast(display), ddpi, hdpi, vdpi);
        }
        return c.SDL_GetDisplayDPI(display, ddpi, hdpi, vdpi) == 0;
    }
    return false;
}

pub fn getCurrentDisplayMode(display: i32, mode: *c.SDL_DisplayMode) bool {
    if (@hasDecl(c, "SDL_GetCurrentDisplayMode")) {
        if (is_sdl3) {
            const mode_ptr = c.SDL_GetCurrentDisplayMode(@intCast(display));
            if (mode_ptr == null) return false;
            mode.* = mode_ptr.*;
            return true;
        }
        return c.SDL_GetCurrentDisplayMode(display, mode) == 0;
    }
    return false;
}

pub fn startTextInput(window: ?*c.SDL_Window) void {
    if (is_sdl3) {
        _ = c.SDL_StartTextInput(window);
    } else {
        c.SDL_StartTextInput();
    }
}

pub fn stopTextInput(window: ?*c.SDL_Window) void {
    if (is_sdl3) {
        _ = c.SDL_StopTextInput(window);
    } else {
        c.SDL_StopTextInput();
    }
}

pub fn waitEventTimeout(event: *c.SDL_Event, timeout_ms: c_int) bool {
    if (is_sdl3) {
        return c.SDL_WaitEventTimeout(event, timeout_ms);
    }
    return c.SDL_WaitEventTimeout(event, timeout_ms) != 0;
}

pub fn pollEvent(event: *c.SDL_Event) bool {
    if (is_sdl3) {
        return c.SDL_PollEvent(event);
    }
    return c.SDL_PollEvent(event) != 0;
}

pub fn sdlEventSize() usize {
    return @sizeOf(c.SDL_Event);
}

pub fn getMouseState(x: *c_int, y: *c_int) void {
    if (is_sdl3) {
        var fx: f32 = 0;
        var fy: f32 = 0;
        _ = c.SDL_GetMouseState(&fx, &fy);
        x.* = @intFromFloat(fx);
        y.* = @intFromFloat(fy);
    } else {
        _ = c.SDL_GetMouseState(x, y);
    }
}

pub fn keyScancode(event: *const c.SDL_Event) i32 {
    const key = event.key;
    if (@hasField(@TypeOf(key), "keysym")) {
        return @intCast(key.keysym.scancode);
    }
    if (@hasField(@TypeOf(key), "scancode")) {
        return @intCast(key.scancode);
    }
    return -1;
}

pub fn keySym(event: *const c.SDL_Event) i32 {
    const key = event.key;
    if (@hasField(@TypeOf(key), "keysym")) {
        return @intCast(key.keysym.sym);
    }
    if (@hasField(@TypeOf(key), "key")) {
        return @intCast(key.key);
    }
    return 0;
}

pub fn keyRepeat(event: *const c.SDL_Event) u8 {
    const key = event.key;
    if (@hasField(@TypeOf(key), "repeat")) {
        if (is_sdl3) {
            return if (key.repeat) 1 else 0;
        }
        return @intCast(key.repeat);
    }
    return 0;
}

pub fn wheelDelta(event: *const c.SDL_Event) f32 {
    if (is_sdl3) {
        return @as(f32, event.wheel.y);
    }
    return @floatFromInt(event.wheel.y);
}

pub fn textInputSpan(event: *const c.SDL_Event) []const u8 {
    const text = event.text;
    if (@hasField(@TypeOf(text), "text")) {
        return textSpan(text.text);
    }
    return "";
}

pub fn textInputLen(event: *const c.SDL_Event) usize {
    const text = event.text;
    if (@hasField(@TypeOf(text), "text")) {
        if (@hasField(@TypeOf(text), "text_len")) {
            return @intCast(text.text_len);
        }
        if (@hasField(@TypeOf(text), "length")) {
            return @intCast(text.length);
        }
        return textSpan(text.text).len;
    }
    return 0;
}

pub fn textInputPointer(event: *const c.SDL_Event) ?usize {
    const text = event.text;
    if (@hasField(@TypeOf(text), "text")) {
        return pointerValue(text.text);
    }
    return null;
}

pub fn textEditingSpan(event: *const c.SDL_Event) []const u8 {
    const edit = event.edit;
    if (@hasField(@TypeOf(edit), "text")) {
        return textSpan(edit.text);
    }
    return "";
}

pub fn textEditingLen(event: *const c.SDL_Event) usize {
    const edit = event.edit;
    if (@hasField(@TypeOf(edit), "text")) {
        if (@hasField(@TypeOf(edit), "text_len")) {
            return @intCast(edit.text_len);
        }
        if (@hasField(@TypeOf(edit), "length")) {
            return @intCast(edit.length);
        }
        return textSpan(edit.text).len;
    }
    return 0;
}

pub fn textEditingPointer(event: *const c.SDL_Event) ?usize {
    const edit = event.edit;
    if (@hasField(@TypeOf(edit), "text")) {
        return pointerValue(edit.text);
    }
    return null;
}

pub fn textEditingCursor(event: *const c.SDL_Event) i32 {
    const edit = event.edit;
    if (@hasField(@TypeOf(edit), "start")) {
        return @intCast(edit.start);
    }
    if (@hasField(@TypeOf(edit), "cursor")) {
        return @intCast(edit.cursor);
    }
    return 0;
}

pub fn textEditingSelectionLen(event: *const c.SDL_Event) i32 {
    const edit = event.edit;
    if (@hasField(@TypeOf(edit), "length")) {
        return @intCast(edit.length);
    }
    if (@hasField(@TypeOf(edit), "selection_len")) {
        return @intCast(edit.selection_len);
    }
    return 0;
}

fn textSpan(field: anytype) []const u8 {
    return switch (@typeInfo(@TypeOf(field))) {
        .pointer => std.mem.span(field),
        .array => std.mem.span(@as([*:0]const u8, @ptrCast(&field))),
        else => "",
    };
}

fn fieldOffset(comptime T: type, comptime field: []const u8) ?usize {
    if (@hasField(T, field)) {
        return @offsetOf(T, field);
    }
    return null;
}

fn pointerValue(field: anytype) ?usize {
    return switch (@typeInfo(@TypeOf(field))) {
        .pointer => @intFromPtr(field),
        else => null,
    };
}

pub fn textSpanWithLen(field: anytype, len: usize) []const u8 {
    return switch (@typeInfo(@TypeOf(field))) {
        .pointer => field[0..len],
        .array => @as([*]const u8, @ptrCast(&field))[0..len],
        else => "",
    };
}

pub fn glMakeCurrent(window: *c.SDL_Window, context: c.SDL_GLContext) void {
    _ = c.SDL_GL_MakeCurrent(window, context);
}

pub fn glSetSwapInterval(interval: c_int) void {
    _ = c.SDL_GL_SetSwapInterval(interval);
}

pub fn glSwapWindow(window: *c.SDL_Window) void {
    _ = c.SDL_GL_SwapWindow(window);
}

pub fn displayModeRefreshHz(mode: *const c.SDL_DisplayMode) i32 {
    if (is_sdl3) {
        return @intFromFloat(mode.refresh_rate);
    }
    return @intCast(mode.refresh_rate);
}

pub fn getWindowEventId(event: *const c.SDL_Event) u8 {
    if (is_sdl3) {
        return 0;
    }
    return event.window.event;
}

pub fn logSetAllPriority(priority: c.SDL_LogPriority) void {
    if (@hasDecl(c, "SDL_SetLogPriorities")) {
        _ = c.SDL_SetLogPriorities(priority);
    } else {
        _ = c.SDL_LogSetAllPriority(priority);
    }
}

pub fn setTextInputRect(window: ?*c.SDL_Window, rect: *c.SDL_Rect) void {
    if (@hasDecl(c, "SDL_SetTextInputArea")) {
        _ = c.SDL_SetTextInputArea(window, rect, 0);
    } else if (@hasDecl(c, "SDL_SetTextInputRect")) {
        _ = c.SDL_SetTextInputRect(rect);
    }
}

pub fn getPerformanceCounter() u64 {
    return c.SDL_GetPerformanceCounter();
}

pub fn getPerformanceFrequency() u64 {
    return c.SDL_GetPerformanceFrequency();
}

pub fn setClipboardText(text: [*:0]const u8) void {
    _ = c.SDL_SetClipboardText(text);
}

pub fn getClipboardText() ?[]const u8 {
    const ptr = c.SDL_GetClipboardText() orelse return null;
    return std.mem.span(ptr);
}

pub fn freeClipboardText(text: []const u8) void {
    c.SDL_free(@constCast(text.ptr));
}

pub const scancode_count: usize = if (is_sdl3)
    if (@hasDecl(c, "SDL_SCANCODE_COUNT")) @intCast(c.SDL_SCANCODE_COUNT) else 512
else
    @intCast(c.SDL_NUM_SCANCODES);
