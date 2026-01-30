const gl = @import("../ui/renderer/gl.zig");

const sdl = gl.c;

pub fn eventName(event_id: u8) []const u8 {
    return switch (event_id) {
        sdl.SDL_WINDOWEVENT_SHOWN => "shown",
        sdl.SDL_WINDOWEVENT_HIDDEN => "hidden",
        sdl.SDL_WINDOWEVENT_EXPOSED => "exposed",
        sdl.SDL_WINDOWEVENT_MOVED => "moved",
        sdl.SDL_WINDOWEVENT_RESIZED => "resized",
        sdl.SDL_WINDOWEVENT_SIZE_CHANGED => "size_changed",
        sdl.SDL_WINDOWEVENT_MINIMIZED => "minimized",
        sdl.SDL_WINDOWEVENT_MAXIMIZED => "maximized",
        sdl.SDL_WINDOWEVENT_RESTORED => "restored",
        sdl.SDL_WINDOWEVENT_ENTER => "enter",
        sdl.SDL_WINDOWEVENT_LEAVE => "leave",
        sdl.SDL_WINDOWEVENT_FOCUS_GAINED => "focus_gained",
        sdl.SDL_WINDOWEVENT_FOCUS_LOST => "focus_lost",
        sdl.SDL_WINDOWEVENT_CLOSE => "close",
        sdl.SDL_WINDOWEVENT_TAKE_FOCUS => "take_focus",
        sdl.SDL_WINDOWEVENT_HIT_TEST => "hit_test",
        sdl.SDL_WINDOWEVENT_DISPLAY_CHANGED => "display_changed",
        else => "unknown",
    };
}

pub fn isResizeEvent(event_id: u8) bool {
    return event_id == sdl.SDL_WINDOWEVENT_RESIZED or
        event_id == sdl.SDL_WINDOWEVENT_SIZE_CHANGED or
        event_id == sdl.SDL_WINDOWEVENT_MOVED or
        event_id == sdl.SDL_WINDOWEVENT_DISPLAY_CHANGED;
}

pub fn isCloseEvent(event_id: u8) bool {
    return event_id == sdl.SDL_WINDOWEVENT_CLOSE;
}
