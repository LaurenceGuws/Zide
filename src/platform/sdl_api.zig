const std = @import("std");
const builtin = @import("builtin");
pub const is_sdl3 = true;

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
pub const EVENT_MOUSE_BUTTON_DOWN: c_uint = c.SDL_EVENT_MOUSE_BUTTON_DOWN;
pub const EVENT_MOUSE_BUTTON_UP: c_uint = c.SDL_EVENT_MOUSE_BUTTON_UP;
pub const EVENT_MOUSE_WHEEL: c_uint = c.SDL_EVENT_MOUSE_WHEEL;

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
    if (@hasDecl(c, "SDL_EVENT_WINDOW_SHOWN") and event_type == c.SDL_EVENT_WINDOW_SHOWN) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_HIDDEN") and event_type == c.SDL_EVENT_WINDOW_HIDDEN) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_EXPOSED") and event_type == c.SDL_EVENT_WINDOW_EXPOSED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_MOVED") and event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_RESIZED") and event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_SIZE_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return true;
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

pub fn windowEventName(event_type: c_uint) []const u8 {
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
    if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return "display_scale_changed";
    return "unknown";
}

pub fn isResizeEvent(event_type: c_uint) bool {
    if (@hasDecl(c, "SDL_EVENT_WINDOW_RESIZED") and event_type == c.SDL_EVENT_WINDOW_RESIZED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_SIZE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_SIZE_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_MOVED") and event_type == c.SDL_EVENT_WINDOW_MOVED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_CHANGED) return true;
    if (@hasDecl(c, "SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED") and event_type == c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return true;
    return false;
}

pub fn isCloseEvent(event_type: c_uint) bool {
    return @hasDecl(c, "SDL_EVENT_WINDOW_CLOSE_REQUESTED") and event_type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED;
}

pub fn isFocusGainedEvent(event_type: c_uint) bool {
    return @hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_GAINED") and event_type == c.SDL_EVENT_WINDOW_FOCUS_GAINED;
}

pub fn isFocusLostEvent(event_type: c_uint) bool {
    return @hasDecl(c, "SDL_EVENT_WINDOW_FOCUS_LOST") and event_type == c.SDL_EVENT_WINDOW_FOCUS_LOST;
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
    const high_dpi = if (@hasDecl(c, "SDL_WINDOW_HIGH_PIXEL_DENSITY"))
        @as(c_uint, @intCast(c.SDL_WINDOW_HIGH_PIXEL_DENSITY))
    else if (@hasDecl(c, "SDL_WINDOW_ALLOW_HIGHDPI"))
        @as(c_uint, @intCast(c.SDL_WINDOW_ALLOW_HIGHDPI))
    else
        0;
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
    if (@hasDecl(c, "SDL_GL_DestroyContext")) {
        _ = c.SDL_GL_DestroyContext(context);
    } else {
        c.SDL_GL_DeleteContext(context);
    }
}

pub fn getWindowSize(window: *c.SDL_Window, w: *c_int, h: *c_int) void {
    _ = c.SDL_GetWindowSize(window, w, h);
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
        return c.SDL_GetDisplayBounds(@intCast(display), rect);
    }
    return false;
}

pub fn getDisplayDpi(display: i32, ddpi: *f32, hdpi: *f32, vdpi: *f32) bool {
    if (@hasDecl(c, "SDL_GetDisplayDPI")) {
        return c.SDL_GetDisplayDPI(@intCast(display), ddpi, hdpi, vdpi);
    }
    return false;
}

pub fn getCurrentDisplayMode(display: i32, mode: *c.SDL_DisplayMode) bool {
    if (@hasDecl(c, "SDL_GetCurrentDisplayMode")) {
        const mode_ptr = c.SDL_GetCurrentDisplayMode(@intCast(display));
        if (mode_ptr == null) return false;
        mode.* = mode_ptr.*;
        return true;
    }
    return false;
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

pub fn sdlEventSize() usize {
    return @sizeOf(c.SDL_Event);
}

pub fn getMouseState(x: *f32, y: *f32) void {
    _ = c.SDL_GetMouseState(x, y);
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
        return if (key.repeat) 1 else 0;
    }
    return 0;
}

pub fn keyModBits(event: *const c.SDL_Event) u32 {
    const key = event.key;
    if (@hasField(@TypeOf(key), "mod")) return @intCast(key.mod);
    if (@hasField(@TypeOf(key), "keysym") and @hasField(@TypeOf(key.keysym), "mod")) {
        return @intCast(key.keysym.mod);
    }
    return 0;
}

pub fn keycodeFromScancodeMods(scancode: i32, shift: bool, alt: bool, ctrl: bool, super: bool) i32 {
    if (!@hasDecl(c, "SDL_GetKeyFromScancode")) return 0;
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
    return @intFromFloat(mode.refresh_rate);
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

pub const scancode_count: usize = if (@hasDecl(c, "SDL_SCANCODE_COUNT")) @intCast(c.SDL_SCANCODE_COUNT) else 512;
