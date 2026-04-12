const std = @import("std");
const builtin = @import("builtin");
const c_api = @import("../terminal/ffi/c_api.zig");
const ffi_shared = @import("../terminal/ffi/shared.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");

const c = @cImport({
    @cInclude("stdlib.h");
});

const initial_cols: u16 = 80;
const initial_rows: u16 = 24;
const initial_cell_width: u16 = 8;
const initial_cell_height: u16 = 16;
const app_files_path = "/data/data/dev.zide.terminal/files";
const userland_prefix = app_files_path ++ "/usr";
const userland_home = app_files_path ++ "/home";
const userland_tmp = "/data/user/0/dev.zide.terminal/tmp";
const shell_path: [:0]const u8 = userland_prefix ++ "/bin/bash";
const bashrc_path = userland_home ++ "/.bashrc";
const profile_path = userland_home ++ "/.profile";
const inputrc_path = userland_home ++ "/.inputrc";
const bash_history_path = userland_home ++ "/.bash_history";
const default_bashrc =
    \\# Zide Android Bash defaults
    \\export HISTFILE="$HOME/.bash_history"
    \\export HISTSIZE=5000
    \\export HISTFILESIZE=10000
    \\shopt -s histappend 2>/dev/null
    \\__zide_base_prompt_command="${PROMPT_COMMAND:-}"
    \\__zide_prompt_command() {
    \\    local exit_code=$?
    \\    if [ "$exit_code" -eq 0 ]; then
    \\        PS1='[zide \w]\$ '
    \\    else
    \\        PS1="[zide \w !${exit_code}]\\$ "
    \\    fi
    \\    history -a
    \\    history -n
    \\    if [ -n "$__zide_base_prompt_command" ]; then
    \\        eval "$__zide_base_prompt_command"
    \\    fi
    \\}
    \\PROMPT_COMMAND=__zide_prompt_command
    \\cd "$HOME" 2>/dev/null || true
    \\
;
const default_profile =
    \\# Zide Android profile
    \\if [ -f "$HOME/.bashrc" ]; then
    \\    . "$HOME/.bashrc"
    \\fi
    \\
;
const default_inputrc =
    \\set enable-bracketed-paste on
    \\set bell-style none
    \\
;

pub const StartStatus = enum(i32) {
    none = 0,
    started = 1,
    unsupported = 2,
    create_failed = 3,
    resize_failed = 4,
    start_failed = 5,
    send_failed = 6,
    poll_failed = 7,
};

const Session = struct {
    handle: ?*c_api.ZideTerminalHandle,
    cols: u16,
    rows: u16,
    cell_width: u16,
    cell_height: u16,

    fn deinit(self: *Session) void {
        c_api.zide_terminal_destroy(self.handle);
        self.handle = null;
    }
};

var session: ?Session = null;
var last_start_status: StartStatus = .none;

pub fn lastStartStatus() StartStatus {
    return last_start_status;
}

pub fn activeRuntimeShell() ?*terminal_runtime.TerminalRuntimeShell {
    const active = session orelse return null;
    const handle = ffi_shared.fromOpaqueActive(active.handle) orelse return null;
    return handle.shell;
}

pub fn isAlive() bool {
    const active = session orelse return false;
    return c_api.zide_terminal_is_alive(active.handle) != 0;
}

pub fn needsRedraw() bool {
    const active = session orelse return false;
    return c_api.zide_terminal_needs_redraw(active.handle) != 0;
}

pub const SendStatus = enum(i32) {
    ok = 0,
    no_session = 1,
    send_failed = 2,
};

pub fn sendText(text: []const u8) SendStatus {
    const active = session orelse return .no_session;
    if (text.len == 0) return .ok;
    if (c_api.zide_terminal_send_text(active.handle, text.ptr, text.len) != 0) {
        return .send_failed;
    }
    return .ok;
}

pub fn sendCodepoint(cp: u21) SendStatus {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(cp, &buf) catch return .send_failed;
    return sendText(buf[0..len]);
}

pub fn resizeToGrid(cols: u16, rows: u16, cell_width: u16, cell_height: u16) !bool {
    const active = session orelse return false;
    if (cols == 0 or rows == 0 or cell_width == 0 or cell_height == 0) return false;
    if (active.cols == cols and active.rows == rows and active.cell_width == cell_width and active.cell_height == cell_height) {
        return false;
    }

    if (c_api.zide_terminal_resize(active.handle, cols, rows, cell_width, cell_height) != 0) {
        last_start_status = .resize_failed;
        return error.ResizeFailed;
    }

    session = .{
        .handle = active.handle,
        .cols = cols,
        .rows = rows,
        .cell_width = cell_width,
        .cell_height = cell_height,
    };
    try poll();
    return true;
}

pub fn restart() !void {
    if (!(builtin.target.os.tag == .linux and builtin.target.abi == .android)) {
        last_start_status = .unsupported;
        return error.Unsupported;
    }

    stop();
    try configureUserlandEnvironment();
    var handle: ?*c_api.ZideTerminalHandle = null;
    if (c_api.zide_terminal_create(null, &handle) != 0) {
        last_start_status = .create_failed;
        return error.CreateFailed;
    }
    errdefer c_api.zide_terminal_destroy(handle);

    if (c_api.zide_terminal_resize(handle, initial_cols, initial_rows, initial_cell_width, initial_cell_height) != 0) {
        last_start_status = .resize_failed;
        return error.ResizeFailed;
    }

    if (c_api.zide_terminal_start(handle, shell_path.ptr) != 0) {
        last_start_status = .start_failed;
        return error.StartFailed;
    }

    session = .{
        .handle = handle,
        .cols = initial_cols,
        .rows = initial_rows,
        .cell_width = initial_cell_width,
        .cell_height = initial_cell_height,
    };
    last_start_status = .started;
    try poll();
}

fn configureUserlandEnvironment() !void {
    try makePathAbsolute(userland_home);
    try makePathAbsolute(userland_tmp);
    try makePathAbsolute(userland_prefix ++ "/tmp");
    try makePathAbsolute(userland_home ++ "/.config");
    try makePathAbsolute(userland_home ++ "/.local/share");
    try makePathAbsolute(userland_home ++ "/.local/state");
    try ensureFileWithContentsIfMissing(bashrc_path, default_bashrc);
    try ensureFileWithContentsIfMissing(profile_path, default_profile);
    try ensureFileWithContentsIfMissing(inputrc_path, default_inputrc);
    try ensureFileWithContentsIfMissing(bash_history_path, "");

    setEnv("PREFIX", userland_prefix);
    setEnv("HOME", userland_home);
    setEnv("TMPDIR", userland_tmp);
    setEnv("PATH", userland_prefix ++ "/bin:/system/bin");
    setEnv("SHELL", shell_path);
    setEnv("ZIDE_LAUNCH_CWD", userland_home);
    setEnv("ZIDE_BASH_RCFILE", bashrc_path);
    setEnv("SSL_CERT_FILE", userland_prefix ++ "/etc/tls/cert.pem");
    setEnv("CURL_CA_BUNDLE", userland_prefix ++ "/etc/tls/cert.pem");
    setEnv("VIMRUNTIME", userland_prefix ++ "/share/nvim/runtime");
    setEnv("XDG_CONFIG_HOME", userland_home ++ "/.config");
    setEnv("XDG_DATA_HOME", userland_home ++ "/.local/share");
    setEnv("XDG_STATE_HOME", userland_home ++ "/.local/state");
    setEnv("TERMINFO", userland_prefix ++ "/share/terminfo");
    setEnv("LD_LIBRARY_PATH", userland_prefix ++ "/lib");
    setEnv("INPUTRC", inputrc_path);
    setEnv("HISTFILE", bash_history_path);
}

fn setEnv(name: [:0]const u8, value: [:0]const u8) void {
    _ = c.setenv(name.ptr, value.ptr, 1);
}

fn makePathAbsolute(dir_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute("/", .{});
    defer dir.close();
    const relative = std.mem.trimLeft(u8, dir_path, "/");
    if (relative.len == 0) return;
    try dir.makePath(relative);
}

fn ensureFileWithContentsIfMissing(path: []const u8, contents: []const u8) !void {
    std.fs.accessAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            const file = try std.fs.createFileAbsolute(path, .{ .truncate = false });
            defer file.close();
            try file.writeAll(contents);
        },
        else => return err,
    };
}

pub fn stop() void {
    if (session) |*active| {
        active.deinit();
        session = null;
    }
}

pub fn poll() !void {
    const active = session orelse return;

    if (c_api.zide_terminal_poll(active.handle) != 0) {
        last_start_status = .poll_failed;
        return error.PollFailed;
    }

    var events: c_api.ZideTerminalEventBuffer = .{};
    if (c_api.zide_terminal_event_drain(active.handle, &events) != 0) {
        last_start_status = .poll_failed;
        return error.EventDrainFailed;
    }
    defer c_api.zide_terminal_events_free(&events);
}
