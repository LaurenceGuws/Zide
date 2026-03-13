const std = @import("std");
const builtin = @import("builtin");

pub const c = @cImport({
    if (builtin.target.os.tag == .windows) {
        // Work around Zig translate-c emitting a strong definition for
        // `_Avx2WmemEnabledWeakValue` from the Windows UCRT `wchar.h`, which
        // then duplicates the symbol from `libucrt` at link time.
        @cDefine("_INC_WCHAR", "1");
    }
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_opengl.h");
});

pub const EVENT_QUIT: c_uint = c.SDL_EVENT_QUIT;
pub const EVENT_WINDOW: c_uint = c.SDL_EVENT_WINDOW_SHOWN;
pub const EVENT_KEY_DOWN: c_uint = c.SDL_EVENT_KEY_DOWN;
pub const EVENT_KEY_UP: c_uint = c.SDL_EVENT_KEY_UP;
pub const EVENT_TEXT_INPUT: c_uint = c.SDL_EVENT_TEXT_INPUT;
pub const EVENT_TEXT_EDITING: c_uint = c.SDL_EVENT_TEXT_EDITING;
pub const EVENT_MOUSE_MOTION: c_uint = c.SDL_EVENT_MOUSE_MOTION;
pub const EVENT_MOUSE_BUTTON_DOWN: c_uint = c.SDL_EVENT_MOUSE_BUTTON_DOWN;
pub const EVENT_MOUSE_BUTTON_UP: c_uint = c.SDL_EVENT_MOUSE_BUTTON_UP;
pub const EVENT_MOUSE_WHEEL: c_uint = c.SDL_EVENT_MOUSE_WHEEL;

pub const TextInputLayout = struct {
    size: usize,
    offset_type: usize,
    offset_reserved: usize,
    offset_timestamp: usize,
    offset_window_id: usize,
    offset_text: usize,
};

pub const TextEditingLayout = struct {
    size: usize,
    offset_type: usize,
    offset_reserved: usize,
    offset_timestamp: usize,
    offset_window_id: usize,
    offset_text: usize,
    offset_start: usize,
    offset_length: usize,
    offset_cursor: usize,
    offset_selection_len: usize,
};

pub fn textInputLayout() TextInputLayout {
    return .{
        .size = @sizeOf(c.SDL_TextInputEvent),
        .offset_type = @offsetOf(c.SDL_TextInputEvent, "type"),
        .offset_reserved = @offsetOf(c.SDL_TextInputEvent, "reserved"),
        .offset_timestamp = @offsetOf(c.SDL_TextInputEvent, "timestamp"),
        .offset_window_id = @offsetOf(c.SDL_TextInputEvent, "windowID"),
        .offset_text = @offsetOf(c.SDL_TextInputEvent, "text"),
    };
}

pub fn textEditingLayout() TextEditingLayout {
    return .{
        .size = @sizeOf(c.SDL_TextEditingEvent),
        .offset_type = @offsetOf(c.SDL_TextEditingEvent, "type"),
        .offset_reserved = @offsetOf(c.SDL_TextEditingEvent, "reserved"),
        .offset_timestamp = @offsetOf(c.SDL_TextEditingEvent, "timestamp"),
        .offset_window_id = @offsetOf(c.SDL_TextEditingEvent, "windowID"),
        .offset_text = @offsetOf(c.SDL_TextEditingEvent, "text"),
        .offset_start = @offsetOf(c.SDL_TextEditingEvent, "start"),
        .offset_length = @offsetOf(c.SDL_TextEditingEvent, "length"),
        .offset_cursor = @offsetOf(c.SDL_TextEditingEvent, "start"),
        .offset_selection_len = @offsetOf(c.SDL_TextEditingEvent, "length"),
    };
}

pub fn isWindowEventType(event_type: c_uint) bool {
    if (event_type == c.SDL_EVENT_WINDOW_SHOWN) return true;
    if (event_type == c.SDL_EVENT_WINDOW_HIDDEN) return true;
    if (event_type == c.SDL_EVENT_WINDOW_EXPOSED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MINIMIZED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MAXIMIZED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_RESTORED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MOUSE_ENTER) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MOUSE_LEAVE) return true;
    if (event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST) return true;
    if (event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_HIT_TEST) return true;
    return false;
}

pub fn windowEventName(event_type: c_uint) []const u8 {
    if (event_type == c.SDL_EVENT_WINDOW_SHOWN) return "shown";
    if (event_type == c.SDL_EVENT_WINDOW_HIDDEN) return "hidden";
    if (event_type == c.SDL_EVENT_WINDOW_EXPOSED) return "exposed";
    if (event_type == c.SDL_EVENT_WINDOW_MOVED) return "moved";
    if (event_type == c.SDL_EVENT_WINDOW_RESIZED) return "resized";
    if (event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return "size_changed";
    if (event_type == c.SDL_EVENT_WINDOW_MINIMIZED) return "minimized";
    if (event_type == c.SDL_EVENT_WINDOW_MAXIMIZED) return "maximized";
    if (event_type == c.SDL_EVENT_WINDOW_RESTORED) return "restored";
    if (event_type == c.SDL_EVENT_WINDOW_MOUSE_ENTER) return "enter";
    if (event_type == c.SDL_EVENT_WINDOW_MOUSE_LEAVE) return "leave";
    if (event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED) return "focus_gained";
    if (event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST) return "focus_lost";
    if (event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED) return "close";
    if (event_type == c.SDL_EVENT_WINDOW_HIT_TEST) return "hit_test";
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return "display_changed";
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return "display_scale_changed";
    return "unknown";
}

pub fn isResizeEvent(event_type: c_uint) bool {
    if (event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
    if (event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return true;
    return false;
}

pub fn isCloseEvent(event_type: c_uint) bool {
    return event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
}

pub fn isFocusGainedEvent(event_type: c_uint) bool {
    return event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED;
}

pub fn isFocusLostEvent(event_type: c_uint) bool {
    return event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST;
}

pub fn windowEventData1(event: *const c.SDL_Event) i32 {
    return @intCast(event.window.data1);
}

pub fn windowEventData2(event: *const c.SDL_Event) i32 {
    return @intCast(event.window.data2);
}

pub fn setHint(name: [*:0]const u8, value: [*:0]const u8) void {
    _ = c.SDL_SetHint(name, value);
}

pub fn init(flags: c_uint) bool {
    return c.SDL_Init(flags);
}

pub fn defaultInitFlags() c_uint {
    return @intCast(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS);
}

pub fn quit() void {
    c.SDL_Quit();
}

pub const GlAttr = c.SDL_GLAttr;

pub fn glSetAttribute(attr: GlAttr, value: c_int) void {
    _ = c.SDL_GL_SetAttribute(attr, value);
}

pub fn createWindow(title: [*:0]const u8, width: c_int, height: c_int) ?*c.SDL_Window {
    const high_dpi = @as(c_uint, @intCast(c.SDL_WINDOW_HIGH_PIXEL_DENSITY));
    const base_flags: c_uint = @intCast(c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
    const flags: c_uint = base_flags | high_dpi;
    return c.SDL_CreateWindow(title, width, height, flags);
}

pub fn destroyWindow(window: *c.SDL_Window) void {
    c.SDL_DestroyWindow(window);
}

pub fn glCreateContext(window: *c.SDL_Window) ?c.SDL_GLContext {
    return c.SDL_GL_CreateContext(window);
}

pub fn glDeleteContext(context: c.SDL_GLContext) void {
    _ = c.SDL_GL_DestroyContext(context);
}

pub fn glGetSwapInterval() i32 {
    var interval: c_int = 0;
    if (!c.SDL_GL_GetSwapInterval(&interval)) return 0;
    return @intCast(interval);
}

pub fn getWindowSize(window: *c.SDL_Window, w: *c_int, h: *c_int) void {
    _ = c.SDL_GetWindowSize(window, w, h);
}

pub fn getDrawableSize(window: *c.SDL_Window, w: *c_int, h: *c_int) void {
    _ = c.SDL_GetWindowSizeInPixels(window, w, h);
}

pub fn getWindowDisplayIndex(window: *c.SDL_Window) i32 {
    return @intCast(c.SDL_GetDisplayForWindow(window));
}

pub fn getWindowDisplayScale(window: *c.SDL_Window) f32 {
    return c.SDL_GetWindowDisplayScale(window);
}

pub fn getWindowPixelDensity(window: *c.SDL_Window) f32 {
    return c.SDL_GetWindowPixelDensity(window);
}

pub fn getDisplayBounds(display: i32, rect: *c.SDL_Rect) bool {
    return c.SDL_GetDisplayBounds(@intCast(display), rect);
}

pub fn getCurrentDisplayMode(display: i32, mode: *c.SDL_DisplayMode) bool {
    const mode_ptr = c.SDL_GetCurrentDisplayMode(@intCast(display));
    if (mode_ptr == null) return false;
    mode.* = mode_ptr.*;
    return true;
}

pub fn startTextInput(window: ?*c.SDL_Window) void {
    _ = c.SDL_StartTextInput(window);
}

pub fn stopTextInput(window: ?*c.SDL_Window) void {
    _ = c.SDL_StopTextInput(window);
}

pub fn waitEventTimeout(event: *c.SDL_Event, timeout_ms: c_int) bool {
    return c.SDL_WaitEventTimeout(event, timeout_ms);
}

pub fn pollEvent(event: *c.SDL_Event) bool {
    return c.SDL_PollEvent(event);
}

pub fn setEventEnabled(event_type: c_uint, enabled: bool) void {
    _ = c.SDL_SetEventEnabled(event_type, enabled);
}

pub fn sdlEventSize() usize {
    return @sizeOf(c.SDL_Event);
}

pub fn getMouseState(x: *f32, y: *f32) void {
    _ = c.SDL_GetMouseState(x, y);
}

pub fn keyScancode(event: *const c.SDL_Event) i32 {
    return @intCast(event.key.scancode);
}

pub fn keySym(event: *const c.SDL_Event) i32 {
    return @intCast(event.key.key);
}

pub fn keyRepeat(event: *const c.SDL_Event) u8 {
    return if (event.key.repeat) 1 else 0;
}

pub fn keyModBits(event: *const c.SDL_Event) u32 {
    return @intCast(event.key.mod);
}

pub fn mouseButtonClicks(event: *const c.SDL_Event) u8 {
    return @intCast(event.button.clicks);
}

pub fn mouseButtonX(event: *const c.SDL_Event) f32 {
    return event.button.x;
}

pub fn mouseButtonY(event: *const c.SDL_Event) f32 {
    return event.button.y;
}

pub fn keycodeFromScancodeMods(scancode: i32, shift: bool, alt: bool, ctrl: bool, super: bool) i32 {
    var raw_modstate: c_uint = @intCast(c.SDL_KMOD_NONE);
    if (shift) raw_modstate |= @as(c_uint, @intCast(c.SDL_KMOD_SHIFT));
    if (alt) raw_modstate |= @as(c_uint, @intCast(c.SDL_KMOD_ALT));
    if (ctrl) raw_modstate |= @as(c_uint, @intCast(c.SDL_KMOD_CTRL));
    if (super) raw_modstate |= @as(c_uint, @intCast(c.SDL_KMOD_GUI));
    const modstate: c.SDL_Keymod = @intCast(raw_modstate);
    const sdl_scancode: c.SDL_Scancode = @intCast(scancode);
    return @intCast(c.SDL_GetKeyFromScancode(sdl_scancode, modstate, true));
}

pub fn keycodeFromScancode(scancode: i32, shift: bool) i32 {
    return keycodeFromScancodeMods(scancode, shift, false, false, false);
}

pub fn keycodeToCodepoint(keycode: i32) ?u32 {
    if (keycode <= 0) return null;
    const cp: u32 = @intCast(keycode);
    if (cp < 0x20 or cp == 0x7f) return null;
    if (cp > 0x10FFFF) return null;
    if (!std.unicode.utf8ValidCodepoint(@as(u21, @intCast(cp)))) return null;
    return cp;
}

pub fn wheelDelta(event: *const c.SDL_Event) f32 {
    return @as(f32, event.wheel.y);
}

pub fn textInputSpan(event: *const c.SDL_Event) []const u8 {
    return textSpan(event.text.text);
}

pub fn textInputLen(event: *const c.SDL_Event) usize {
    return textSpan(event.text.text).len;
}

pub fn textInputPointer(event: *const c.SDL_Event) ?usize {
    return pointerValue(event.text.text);
}

pub fn textEditingSpan(event: *const c.SDL_Event) []const u8 {
    return textSpan(event.edit.text);
}

pub fn textEditingLen(event: *const c.SDL_Event) usize {
    return textSpan(event.edit.text).len;
}

pub fn textEditingPointer(event: *const c.SDL_Event) ?usize {
    return pointerValue(event.edit.text);
}

pub fn textEditingCursor(event: *const c.SDL_Event) i32 {
    return @intCast(event.edit.start);
}

pub fn textEditingSelectionLen(event: *const c.SDL_Event) i32 {
    return @intCast(event.edit.length);
}

fn textSpan(field: anytype) []const u8 {
    return switch (@typeInfo(@TypeOf(field))) {
        .pointer => std.mem.span(field),
        .array => std.mem.span(@as([*:0]const u8, @ptrCast(&field))),
        else => "",
    };
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
    return @intFromFloat(mode.refresh_rate);
}

pub fn logSetAllPriority(priority: c.SDL_LogPriority) void {
    _ = c.SDL_SetLogPriorities(priority);
}

pub fn setTextInputRect(window: ?*c.SDL_Window, rect: *c.SDL_Rect) void {
    _ = c.SDL_SetTextInputArea(window, rect, 0);
}

pub fn getPerformanceCounter() u64 {
    return c.SDL_GetPerformanceCounter();
}

pub fn getPerformanceFrequency() u64 {
    return c.SDL_GetPerformanceFrequency();
}

pub fn getCurrentVideoDriver() ?[]const u8 {
    const ptr = c.SDL_GetCurrentVideoDriver() orelse return null;
    return std.mem.span(ptr);
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

pub fn getClipboardData(mime_type: [*:0]const u8) ?[]const u8 {
    var size: usize = 0;
    const ptr = c.SDL_GetClipboardData(mime_type, &size) orelse return null;
    const bytes: [*]const u8 = @ptrCast(ptr);
    return bytes[0..size];
}

pub fn freeClipboardData(data: []const u8) void {
    if (data.len == 0) return;
    c.SDL_free(@constCast(data.ptr));
}

pub const scancode_count: usize = @intCast(c.SDL_SCANCODE_COUNT);
