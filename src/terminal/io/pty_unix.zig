const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const PtySize = @import("pty.zig").PtySize;

const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("fcntl.h");
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
    @cInclude("pty.h");
    @cInclude("stdlib.h");
});

pub const Pty = struct {
    master_fd: posix.fd_t,
    child_pid: ?posix.pid_t,

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
        };
    }

    pub fn deinit(self: *Pty) void {
        if (self.child_pid) |pid| {
            _ = posix.kill(pid, posix.SIG.TERM) catch {};
            _ = posix.waitpid(pid, 0);
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
        return posix.write(self.master_fd, data);
    }

    pub fn read(self: *Pty, buffer: []u8) !?usize {
        const n = posix.read(self.master_fd, buffer) catch |err| {
            if (err == error.WouldBlock) return null;
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
                if (res.status.exited()) {
                    return @intCast(res.status.exitCode());
                }
                return -1;
            }
        }
        return null;
    }

    pub fn hasData(self: *Pty) bool {
        var fds = [1]posix.pollfd{
            .{
                .fd = self.master_fd,
                .events = posix.POLL.IN,
                .revents = 0,
            },
        };
        const rc = posix.poll(&fds, 0) catch return false;
        return rc > 0 and (fds[0].revents & posix.POLL.IN) != 0;
    }

    pub fn waitForData(self: *Pty, timeout_ms: i32) bool {
        var fds = [1]posix.pollfd{
            .{
                .fd = self.master_fd,
                .events = posix.POLL.IN,
                .revents = 0,
            },
        };
        const rc = posix.poll(&fds, timeout_ms) catch return false;
        return rc > 0 and (fds[0].revents & posix.POLL.IN) != 0;
    }
};

fn setNonBlocking(fd: posix.fd_t) !void {
    const flags = posix.fcntl(fd, posix.F.GETFL, 0) catch 0;
    _ = posix.fcntl(fd, posix.F.SETFL, @as(u32, @intCast(flags)) | c.O_NONBLOCK) catch return error.OpenPtyFailed;
}

fn childProcess(slave_fd: posix.fd_t, shell: ?[:0]const u8) !void {
    _ = posix.setsid() catch {};
    _ = c.ioctl(@intCast(slave_fd), c.TIOCSCTTY, @as(c_ulong, 0));

    var termios: c.struct_termios = undefined;
    if (c.tcgetattr(@intCast(slave_fd), &termios) == 0) {
        termios.c_iflag |= c.IUTF8;
        _ = c.tcsetattr(@intCast(slave_fd), c.TCSANOW, &termios);
    }

    _ = posix.dup2(slave_fd, 0) catch {};
    _ = posix.dup2(slave_fd, 1) catch {};
    _ = posix.dup2(slave_fd, 2) catch {};
    if (slave_fd > 2) posix.close(slave_fd);

    const shell_path = shell orelse defaultShell();
    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));

    const term = if (terminfoExists("xterm-kitty")) "xterm-kitty" else "xterm-256color";
    _ = c.setenv("TERM", term, 1);
    if (std.c.getenv("INPUTRC") == null) {
        const pid = c.getpid();
        var path_buf: [128]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "/tmp/zide-inputrc-{d}", .{pid});
        if (std.fs.cwd().createFile(path, .{ .truncate = true, .read = false })) |file| {
            defer file.close();
            try file.writeAll("$include ~/.inputrc\nset enable-bracketed-paste on\n");
            _ = c.setenv("INPUTRC", path.ptr, 1);
        } else |_| {}
    }

    if (builtin.os.tag == .macos and shell == null) {
        const argv = [_:null]?[*:0]const u8{
            "/usr/bin/login",
            "-pfl",
            shell_path.ptr,
        };
        _ = posix.execvpeZ(argv[0].?, &argv, envp) catch {};
        posix.exit(127);
    }

    const argv = [_:null]?[*:0]const u8{ shell_path.ptr };
    _ = posix.execvpeZ(shell_path.ptr, &argv, envp) catch {};
    posix.exit(127);
}

fn defaultShell() [:0]const u8 {
    if (std.c.getenv("SHELL")) |shell| {
        return std.mem.sliceTo(shell, 0);
    }
    return "/bin/sh";
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

fn terminfoInDir(dir_c: ?[*:0]const u8, name: []const u8) bool {
    if (dir_c == null) return false;
    return terminfoInDirSlice(std.mem.sliceTo(dir_c.?, 0), name);
}

fn terminfoInDirSlice(dir: []const u8, name: []const u8) bool {
    if (dir.len == 0 or name.len == 0) return false;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const subdir = name[0];
    const path = std.fmt.bufPrint(&buf, "{s}/{c}/{s}", .{ dir, subdir, name }) catch return false;
    if (std.fs.openFileAbsolute(path, .{ .mode = .read_only })) |file| {
        file.close();
        return true;
    } else |_| {
        return false;
    }
}
