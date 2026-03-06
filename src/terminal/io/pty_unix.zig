const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const PtySize = @import("pty.zig").PtySize;
const app_logger = @import("../../app_logger.zig");

const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
    @cInclude("pty.h");
    @cInclude("stdlib.h");
    @cInclude("signal.h");
    @cInclude("sys/prctl.h");
});

pub const Pty = struct {
    master_fd: posix.fd_t,
    child_pid: ?posix.pid_t,
    cached_fg_pgrp: c.pid_t,
    cached_fg_name_len: usize,
    cached_fg_name: [128]u8,

    pub fn init(_: std.mem.Allocator, size: PtySize, shell: ?[:0]const u8) !Pty {
        var master_fd: c_int = -1;
        var slave_fd: c_int = -1;
        var winsize = c.struct_winsize{
            .ws_row = size.rows,
            .ws_col = size.cols,
            .ws_xpixel = size.cell_width * size.cols,
            .ws_ypixel = size.cell_height * size.rows,
        };

        if (c.openpty(&master_fd, &slave_fd, null, null, &winsize) != 0) {
            return error.OpenPtyFailed;
        }

        try setNonBlocking(@intCast(master_fd));

        const pid = try posix.fork();
        if (pid == 0) {
            childProcess(@intCast(slave_fd), shell) catch {
                posix.exit(1);
            };
            unreachable;
        }

        // Parent owns master only.
        posix.close(@intCast(slave_fd));

        return Pty{
            .master_fd = @intCast(master_fd),
            .child_pid = pid,
            .cached_fg_pgrp = 0,
            .cached_fg_name_len = 0,
            .cached_fg_name = [_]u8{0} ** 128,
        };
    }

    pub fn deinit(self: *Pty) void {
        if (self.child_pid) |pid| {
            terminateProcessTree(pid);
            reapChildWithDeadline(pid);
            self.child_pid = null;
        }
        posix.close(self.master_fd);
    }

    pub fn resize(self: *Pty, size: PtySize) !void {
        var winsize = c.struct_winsize{
            .ws_row = size.rows,
            .ws_col = size.cols,
            .ws_xpixel = size.cell_width * size.cols,
            .ws_ypixel = size.cell_height * size.rows,
        };
        _ = c.ioctl(@intCast(self.master_fd), c.TIOCSWINSZ, &winsize);
    }

    pub fn write(self: *Pty, data: []const u8) !usize {
        if (data.len == 0) return 0;
        var offset: usize = 0;
        while (offset < data.len) {
            const n = posix.write(self.master_fd, data[offset..]) catch |err| {
                if (err == error.WouldBlock) {
                    var fds = [1]posix.pollfd{
                        .{
                            .fd = self.master_fd,
                            .events = posix.POLL.OUT,
                            .revents = 0,
                        },
                    };
                    _ = posix.poll(&fds, 10) catch |poll_err| blk: {
                        app_logger.logger("terminal.env").logf(.warning, "pty write poll failed err={s}", .{@errorName(poll_err)});
                        break :blk 0;
                    };
                    continue;
                }
                return err;
            };
            if (n == 0) break;
            offset += n;
        }
        return offset;
    }

    pub fn read(self: *Pty, buffer: []u8) !?usize {
        const n = posix.read(self.master_fd, buffer) catch |err| {
            if (err == error.WouldBlock) return null;
            if (err == error.InputOutput) return null;
            return err;
        };
        if (n == 0) return null;
        return n;
    }

    pub fn pollExit(self: *Pty) !?i32 {
        if (self.child_pid) |pid| {
            const res = posix.waitpid(pid, posix.W.NOHANG);
            if (res.pid != 0) {
                self.child_pid = null;
                cleanupSpawnTempFilesForPid(pid);
                if (waitStatusExited(res.status)) {
                    return @intCast(waitStatusExitCode(res.status));
                }
                return -1;
            }
        }
        return null;
    }

    pub fn isAlive(self: *Pty) bool {
        if (self.child_pid == null) return false;
        const pid = self.child_pid.?;
        _ = posix.kill(pid, 0) catch |err| switch (err) {
            // Process exists but we don't have permission.
            error.PermissionDenied => return true,
            else => return false,
        };
        return true;
    }

    pub fn hasForegroundProcessOutsideShell(self: *Pty) bool {
        const shell_pid = self.child_pid orelse return false;
        const shell_pgrp = c.getpgid(shell_pid);
        if (shell_pgrp <= 0) return false;
        const foreground_pgrp = c.tcgetpgrp(@intCast(self.master_fd));
        if (foreground_pgrp <= 0) return false;
        return foreground_pgrp != shell_pgrp;
    }

    pub fn foregroundProcessLabel(self: *Pty) ?[]const u8 {
        if (builtin.os.tag != .linux) return null;
        const shell_pid = self.child_pid orelse return null;
        const shell_pgrp = c.getpgid(shell_pid);
        if (shell_pgrp <= 0) return null;
        const foreground_pgrp = c.tcgetpgrp(@intCast(self.master_fd));
        if (foreground_pgrp <= 0 or foreground_pgrp == shell_pgrp) {
            self.cached_fg_pgrp = 0;
            self.cached_fg_name_len = 0;
            return null;
        }
        if (foreground_pgrp == self.cached_fg_pgrp and self.cached_fg_name_len > 0) {
            return self.cached_fg_name[0..self.cached_fg_name_len];
        }

        if (readForegroundProcessName(foreground_pgrp, &self.cached_fg_name)) |name_len| {
            self.cached_fg_pgrp = foreground_pgrp;
            self.cached_fg_name_len = name_len;
            return self.cached_fg_name[0..name_len];
        }

        self.cached_fg_pgrp = foreground_pgrp;
        self.cached_fg_name_len = 0;
        return null;
    }

    pub fn hasData(self: *Pty) bool {
        const log = app_logger.logger("terminal.io");
        var fds = [1]posix.pollfd{
            .{
                .fd = self.master_fd,
                .events = posix.POLL.IN,
                .revents = 0,
            },
        };
        const rc = posix.poll(&fds, 0) catch |err| {
            log.logf(.debug, "pty poll(hasData) failed: {s}", .{@errorName(err)});
            return false;
        };
        return rc > 0 and (fds[0].revents & posix.POLL.IN) != 0;
    }

    pub fn waitForData(self: *Pty, timeout_ms: i32) bool {
        const log = app_logger.logger("terminal.io");
        var fds = [1]posix.pollfd{
            .{
                .fd = self.master_fd,
                .events = posix.POLL.IN,
                .revents = 0,
            },
        };
        const rc = posix.poll(&fds, timeout_ms) catch |err| {
            log.logf(.debug, "pty poll(waitForData) failed timeout={d}: {s}", .{ timeout_ms, @errorName(err) });
            return false;
        };
        return rc > 0 and (fds[0].revents & posix.POLL.IN) != 0;
    }
};

fn readForegroundProcessName(pgrp: c.pid_t, out_buf: *[128]u8) ?usize {
    const log = app_logger.logger("terminal.io");
    var cmdline_path_buf: [64]u8 = undefined;
    const cmdline_path = std.fmt.bufPrint(&cmdline_path_buf, "/proc/{d}/cmdline", .{pgrp}) catch |err| {
        log.logf(.debug, "foreground cmdline path format failed pgrp={d}: {s}", .{ pgrp, @errorName(err) });
        return null;
    };
    if (std.fs.openFileAbsolute(cmdline_path, .{ .mode = .read_only })) |cmdline_file| {
        defer cmdline_file.close();
        var cmdline_buf: [1024]u8 = undefined;
        const n_cmd = cmdline_file.readAll(&cmdline_buf) catch 0;
        if (n_cmd > 0) {
            var first_end: usize = 0;
            while (first_end < n_cmd and cmdline_buf[first_end] != 0) : (first_end += 1) {}
            if (first_end > 0) {
                const first = cmdline_buf[0..first_end];
                const first_base = std.fs.path.basename(first);
                if (std.mem.eql(u8, first_base, "node") or std.mem.eql(u8, first_base, "nodejs")) {
                    const second_start = first_end + 1;
                    if (second_start < n_cmd) {
                        var second_end = second_start;
                        while (second_end < n_cmd and cmdline_buf[second_end] != 0) : (second_end += 1) {}
                        if (second_end > second_start) {
                            const second = cmdline_buf[second_start..second_end];
                            const second_base = std.fs.path.basename(second);
                            if (copyProcessLabel(second_base, out_buf)) |len| return len;
                        }
                    }
                }
                if (copyProcessLabel(first_base, out_buf)) |len| return len;
            }
        }
    } else |_| {}

    var path_buf: [64]u8 = undefined;
    const comm_path = std.fmt.bufPrint(&path_buf, "/proc/{d}/comm", .{pgrp}) catch |err| {
        log.logf(.debug, "foreground comm path format failed pgrp={d}: {s}", .{ pgrp, @errorName(err) });
        return null;
    };
    var file = std.fs.openFileAbsolute(comm_path, .{ .mode = .read_only }) catch |err| {
        log.logf(.debug, "foreground comm open failed pgrp={d}: {s}", .{ pgrp, @errorName(err) });
        return null;
    };
    defer file.close();
    const n = file.readAll(out_buf) catch |err| {
        log.logf(.debug, "foreground comm read failed pgrp={d}: {s}", .{ pgrp, @errorName(err) });
        return null;
    };
    if (n == 0) return null;
    var end = n;
    while (end > 0 and (out_buf[end - 1] == '\n' or out_buf[end - 1] == '\r' or out_buf[end - 1] == ' ' or out_buf[end - 1] == '\t')) : (end -= 1) {}
    if (end == 0) return null;
    return end;
}

fn copyProcessLabel(label: []const u8, out_buf: *[128]u8) ?usize {
    if (label.len == 0) return null;
    var src = label;
    if (std.mem.lastIndexOfScalar(u8, src, '.')) |dot| {
        if (dot > 0 and (std.mem.eql(u8, src[dot..], ".js") or std.mem.eql(u8, src[dot..], ".mjs") or std.mem.eql(u8, src[dot..], ".cjs"))) {
            src = src[0..dot];
        }
    }
    if (src.len == 0) return null;
    const len = @min(src.len, out_buf.len);
    std.mem.copyForwards(u8, out_buf[0..len], src[0..len]);
    return len;
}

fn waitStatusExited(status: u32) bool {
    // POSIX wait status encoding.
    // Mirrors common WIFEXITED macro: true when signal bits are 0.
    return (status & 0x7f) == 0;
}

fn waitStatusExitCode(status: u32) u8 {
    // Mirrors WEXITSTATUS: high byte holds the exit code.
    return @intCast((status >> 8) & 0xff);
}

fn reapChildWithDeadline(pid: posix.pid_t) void {
    const reap_deadline_ms: i64 = 20;
    const start_ms = std.time.milliTimestamp();
    while (true) {
        const res = posix.waitpid(pid, posix.W.NOHANG);
        if (res.pid != 0) return;
        if (std.time.milliTimestamp() - start_ms > reap_deadline_ms) {
            forceKillProcessTree(pid);
            _ = posix.waitpid(pid, 0);
            cleanupSpawnTempFilesForPid(pid);
            return;
        }
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

fn setNonBlocking(fd: posix.fd_t) !void {
    const flags = posix.fcntl(fd, posix.F.GETFL, 0) catch 0;
    _ = posix.fcntl(fd, posix.F.SETFL, @as(u32, @intCast(flags)) | c.O_NONBLOCK) catch return error.OpenPtyFailed;
}

fn childProcess(slave_fd: posix.fd_t, shell: ?[:0]const u8) !void {
    const env_log = app_logger.logger("terminal.env");

    if (builtin.os.tag == .linux) {
        // Ensure child shells are terminated if Zide dies unexpectedly (panic/kill),
        // so we don't leak orphan interactive shells/background trees.
        _ = c.prctl(c.PR_SET_PDEATHSIG, c.SIGTERM);
        if (c.getppid() == 1) posix.exit(1);
    }

    _ = posix.setsid() catch |err| blk: {
        env_log.logf(.warning, "spawn setsid failed err={s}", .{@errorName(err)});
        break :blk 0;
    };
    _ = c.ioctl(@intCast(slave_fd), c.TIOCSCTTY, @as(c_ulong, 0));

    var termios: c.struct_termios = undefined;
    if (c.tcgetattr(@intCast(slave_fd), &termios) == 0) {
        termios.c_iflag |= c.IUTF8;
        _ = c.tcsetattr(@intCast(slave_fd), c.TCSANOW, &termios);
    }

    posix.dup2(slave_fd, 0) catch |err| {
        app_logger.logger("terminal.env").logf(.warning, "spawn dup2 stdin failed err={s}", .{@errorName(err)});
    };
    posix.dup2(slave_fd, 1) catch |err| {
        app_logger.logger("terminal.env").logf(.warning, "spawn dup2 stdout failed err={s}", .{@errorName(err)});
    };
    posix.dup2(slave_fd, 2) catch |err| {
        app_logger.logger("terminal.env").logf(.warning, "spawn dup2 stderr failed err={s}", .{@errorName(err)});
    };
    if (slave_fd > 2) posix.close(slave_fd);

    const shell_path = shell orelse defaultShell();

    const term = chooseTermName(terminfoExists);
    _ = c.setenv("TERM", term, 1);
    if (std.c.getenv("COLORTERM") == null) {
        _ = c.setenv("COLORTERM", "truecolor", 1);
    }
    env_log.logf(.info, 
        "spawn begin shell={s} TERM={s} COLORTERM={s} TERMINFO={s} TERMINFO_DIRS={s} launch_cwd={s}",
        .{
            shell_path,
            term,
            getenvOrUnset("COLORTERM"),
            getenvOrUnset("TERMINFO"),
            getenvOrUnset("TERMINFO_DIRS"),
            getenvOrUnset("ZIDE_LAUNCH_CWD"),
        },
    );
    env_log.logf(.info, 
        "spawn color_env TERM={s} COLORTERM={s} FORCE_COLOR={s} CLICOLOR_FORCE={s} NO_COLOR={s}",
        .{
            getenvOrUnset("TERM"),
            getenvOrUnset("COLORTERM"),
            getenvOrUnset("FORCE_COLOR"),
            getenvOrUnset("CLICOLOR_FORCE"),
            getenvOrUnset("NO_COLOR"),
        },
    );
    if (std.c.getenv("ZIDE_LAUNCH_CWD")) |cwd_c| {
        const cwd = std.mem.sliceTo(cwd_c, 0);
        posix.chdir(cwd) catch |err| {
            env_log.logf(.info, "spawn chdir failed cwd={s} err={s}", .{ cwd, @errorName(err) });
            return err;
        };
        _ = c.setenv("PWD", cwd_c, 1);
        env_log.logf(.info, "spawn chdir ok cwd={s}", .{cwd});
    }
    if (std.c.getenv("INPUTRC") == null) {
        const pid = c.getpid();
        var path_buf: [128:0]u8 = undefined;
        const path = try std.fmt.bufPrintZ(&path_buf, "/tmp/zide-inputrc-{d}", .{pid});
        if (std.fs.cwd().createFile(path, .{ .truncate = true, .read = false })) |file| {
            defer file.close();
            try file.writeAll("$include ~/.inputrc\nset enable-bracketed-paste on\n");
            _ = c.setenv("INPUTRC", path.ptr, 1);
        } else |_| {}
    }

    const shell_base = std.fs.path.basename(shell_path);
    if (std.mem.eql(u8, shell_base, "bash")) {
        const pid = c.getpid();
        var rc_path_buf: [128:0]u8 = undefined;
        const rc_path = try std.fmt.bufPrintZ(&rc_path_buf, "/tmp/zide-bashrc-{d}", .{pid});
        if (std.fs.createFileAbsolute(rc_path, .{ .truncate = true, .read = false })) |file| {
            defer file.close();
            try file.writeAll(
                \\[[ -f ~/.bashrc ]] && . ~/.bashrc
                \\__zide_emit_osc7() {
                \\  local _host
                \\  _host="${HOSTNAME:-$(hostname 2>/dev/null || printf localhost)}"
                \\  printf '\033]7;file://%s%s\007' "$_host" "$PWD"
                \\}
                \\if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
                \\  PROMPT_COMMAND+=("__zide_emit_osc7")
                \\else
                \\  case ";${PROMPT_COMMAND:-};" in
                \\    *";__zide_emit_osc7;"*) ;;
                \\    *) PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND};}__zide_emit_osc7" ;;
                \\  esac
                \\fi
                \\__zide_emit_osc7
            );
            const argv = [_:null]?[*:0]const u8{ shell_path.ptr, "--rcfile", rc_path.ptr, "-i" };
            env_log.logf(.info, "spawn bash rcfile prepared path={s}", .{rc_path});
            env_log.logf(.info, "spawn exec shell={s} (bash rcfile inject)", .{shell_path});
            const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
            const exec_err = posix.execvpeZ(shell_path.ptr, &argv, envp);
            env_log.logf(.warning, "spawn exec shell failed shell={s} err={s}", .{ shell_path, @errorName(exec_err) });
            posix.exit(127);
        } else |err| {
            env_log.logf(.info, "spawn bash rcfile prepare failed path={s} err={s}", .{ rc_path, @errorName(err) });
        }
    }

    if (builtin.os.tag == .macos and shell == null) {
        const argv = [_:null]?[*:0]const u8{
            "/usr/bin/login",
            "-pfl",
            shell_path.ptr,
        };
        const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
        const exec_err = posix.execvpeZ(argv[0].?, &argv, envp);
        env_log.logf(.warning, "spawn exec login failed shell={s} err={s}", .{ shell_path, @errorName(exec_err) });
        posix.exit(127);
    }

    const argv = [_:null]?[*:0]const u8{shell_path.ptr};
    env_log.logf(.info, "spawn exec shell={s}", .{shell_path});
    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
    const exec_err = posix.execvpeZ(shell_path.ptr, &argv, envp);
    env_log.logf(.warning, "spawn exec shell failed shell={s} err={s}", .{ shell_path, @errorName(exec_err) });
    posix.exit(127);
}

fn defaultShell() [:0]const u8 {
    if (std.c.getenv("SHELL")) |shell| {
        return std.mem.sliceTo(shell, 0);
    }
    return "/bin/sh";
}

fn terminateProcessTree(pid: posix.pid_t) void {
    const log = app_logger.logger("terminal.env");
    const pgrp = c.getpgid(pid);
    if (pgrp > 0) {
        const group_pid: posix.pid_t = -@as(posix.pid_t, @intCast(pgrp));
        posix.kill(group_pid, posix.SIG.TERM) catch |err| {
            log.logf(.warning, "spawn terminate group failed pid={d} pgrp={d} err={s}", .{ pid, pgrp, @errorName(err) });
        };
    }
    posix.kill(pid, posix.SIG.TERM) catch |err| {
        log.logf(.warning, "spawn terminate failed pid={d} err={s}", .{ pid, @errorName(err) });
    };
}

fn forceKillProcessTree(pid: posix.pid_t) void {
    const log = app_logger.logger("terminal.env");
    const pgrp = c.getpgid(pid);
    if (pgrp > 0) {
        const group_pid: posix.pid_t = -@as(posix.pid_t, @intCast(pgrp));
        posix.kill(group_pid, posix.SIG.KILL) catch |err| {
            log.logf(.warning, "spawn force-kill group failed pid={d} pgrp={d} err={s}", .{ pid, pgrp, @errorName(err) });
        };
    }
    posix.kill(pid, posix.SIG.KILL) catch |err| {
        log.logf(.warning, "spawn force-kill failed pid={d} err={s}", .{ pid, @errorName(err) });
    };
}

fn cleanupSpawnTempFilesForPid(pid: posix.pid_t) void {
    const log = app_logger.logger("terminal.env");
    var bashrc_buf: [128:0]u8 = undefined;
    const bashrc_path = std.fmt.bufPrintZ(&bashrc_buf, "/tmp/zide-bashrc-{d}", .{pid}) catch |err| {
        log.logf(.warning, "spawn cleanup path format failed kind=bashrc pid={d} err={s}", .{ pid, @errorName(err) });
        return;
    };
    std.fs.deleteFileAbsolute(bashrc_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => log.logf(.debug, "spawn cleanup failed path={s} err={s}", .{ bashrc_path, @errorName(err) }),
    };

    var inputrc_buf: [128:0]u8 = undefined;
    const inputrc_path = std.fmt.bufPrintZ(&inputrc_buf, "/tmp/zide-inputrc-{d}", .{pid}) catch |err| {
        log.logf(.warning, "spawn cleanup path format failed kind=inputrc pid={d} err={s}", .{ pid, @errorName(err) });
        return;
    };
    std.fs.deleteFileAbsolute(inputrc_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => log.logf(.debug, "spawn cleanup failed path={s} err={s}", .{ inputrc_path, @errorName(err) }),
    };
}


fn terminfoExists(name: []const u8) bool {
    if (terminfoInDir(std.c.getenv("TERMINFO"), name)) return true;

    if (std.c.getenv("TERMINFO_DIRS")) |dirs_raw| {
        var it = std.mem.splitScalar(u8, std.mem.sliceTo(dirs_raw, 0), ':');
        while (it.next()) |dir| {
            if (dir.len == 0) {
                if (terminfoInDirSlice("/usr/share/terminfo", name)) return true;
                continue;
            }
            if (terminfoInDirSlice(dir, name)) return true;
        }
    }

    return terminfoInDirSlice("/usr/share/terminfo", name) or
        terminfoInDirSlice("/usr/lib/terminfo", name) or
        terminfoInDirSlice("/lib/terminfo", name) or
        terminfoInDirSlice("/etc/terminfo", name);
}

fn chooseTermName(existsFn: fn ([]const u8) bool) [:0]const u8 {
    if (existsFn("xterm-zide")) return "xterm-zide";
    if (existsFn("zide-256color")) return "zide-256color";
    if (existsFn("zide")) return "zide";
    return "xterm-256color";
}

fn terminfoInDir(dir_c: ?[*:0]const u8, name: []const u8) bool {
    if (dir_c == null) return false;
    return terminfoInDirSlice(std.mem.sliceTo(dir_c.?, 0), name);
}

fn terminfoInDirSlice(dir: []const u8, name: []const u8) bool {
    const log = app_logger.logger("terminal.env");
    if (dir.len == 0 or name.len == 0) return false;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const subdir = name[0];
    const path = std.fmt.bufPrint(&buf, "{s}/{c}/{s}", .{ dir, subdir, name }) catch |err| {
        log.logf(.warning, "terminfo path format failed dir={s} name={s}: {s}", .{ dir, name, @errorName(err) });
        return false;
    };
    if (std.fs.openFileAbsolute(path, .{ .mode = .read_only })) |file| {
        file.close();
        return true;
    } else |_| {
        return false;
    }
}

fn getenvOrUnset(name: [*:0]const u8) []const u8 {
    if (std.c.getenv(name)) |value| return std.mem.sliceTo(value, 0);
    return "<unset>";
}

test "chooseTermName prefers xterm-zide identity for compatibility" {
    const Exists = struct {
        fn has(name: []const u8) bool {
            return std.mem.eql(u8, name, "xterm-zide") or std.mem.eql(u8, name, "zide-256color") or std.mem.eql(u8, name, "zide");
        }
    };
    try std.testing.expectEqualStrings("xterm-zide", chooseTermName(Exists.has));
}

test "chooseTermName falls back to xterm-256color when zide terminfo is unavailable" {
    const Exists = struct {
        fn has(_: []const u8) bool {
            return false;
        }
    };
    try std.testing.expectEqualStrings("xterm-256color", chooseTermName(Exists.has));
}

test "unix pty smoke prefers TERM=xterm-zide when bundled terminfo is installed" {
    if (builtin.target.os.tag == .windows) return;

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var terminfo_dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const terminfo_dir = try tmp.dir.realpath(".", &terminfo_dir_buf);

    try installBundledZideTerminfo(allocator, terminfo_dir);

    const old_terminfo = std.c.getenv("TERMINFO");
    defer {
        if (old_terminfo) |value| {
            _ = c.setenv("TERMINFO", value, 1);
        } else {
            _ = c.unsetenv("TERMINFO");
        }
    }
    _ = c.setenv("TERMINFO", terminfo_dir.ptr, 1);

    var pty = Pty.init(allocator, .{ .rows = 24, .cols = 80, .cell_width = 8, .cell_height = 16 }, "/bin/sh") catch |err| switch (err) {
        error.OpenPtyFailed => return,
        else => return err,
    };
    defer pty.deinit();

    var output = std.ArrayList(u8).empty;
    defer output.deinit(allocator);

    _ = try pty.write("unset HISTFILE; HISTFILE=/dev/null; export HISTFILE; set +o history 2>/dev/null; printf 'TERM=%s\\n' \"$TERM\"; exit\n");

    const start_ms = std.time.milliTimestamp();
    var buf: [4096]u8 = undefined;
    while (std.time.milliTimestamp() - start_ms < 5000) {
        if (!pty.waitForData(50)) continue;
        const n_opt = try pty.read(&buf);
        if (n_opt) |n| {
            if (n == 0) break;
            _ = try output.appendSlice(allocator, buf[0..n]);
            if (std.mem.indexOf(u8, output.items, "TERM=xterm-zide") != null) break;
        }
    }

    try std.testing.expect(std.mem.indexOf(u8, output.items, "TERM=xterm-zide") != null);
}

test "compiled zide terminfo advertises Ms Setulc and Sync" {
    if (builtin.target.os.tag == .windows) return;

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var terminfo_dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const terminfo_dir = try tmp.dir.realpath(".", &terminfo_dir_buf);
    try installBundledZideTerminfo(allocator, terminfo_dir);

    const infocmp = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "infocmp", "-x", "-A", terminfo_dir, "zide" },
    }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer allocator.free(infocmp.stdout);
    defer allocator.free(infocmp.stderr);
    try std.testing.expectEqual(@as(u8, 0), infocmp.term.Exited);
    try std.testing.expect(std.mem.indexOf(u8, infocmp.stdout, "Ms=") != null);
    try std.testing.expect(std.mem.indexOf(u8, infocmp.stdout, "Setulc=") != null);
    try std.testing.expect(std.mem.indexOf(u8, infocmp.stdout, "Sync=") != null);
}

fn installBundledZideTerminfo(allocator: std.mem.Allocator, terminfo_dir: []const u8) !void {
    const compile = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "tic", "-x", "-o", terminfo_dir, "terminfo/zide.terminfo" },
    }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer allocator.free(compile.stdout);
    defer allocator.free(compile.stderr);
    try std.testing.expectEqual(@as(u8, 0), compile.term.Exited);
}
