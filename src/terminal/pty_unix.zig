const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

/// Unix PTY (pseudo-terminal) implementation
pub const Pty = struct {
    master_fd: posix.fd_t,
    slave_fd: posix.fd_t,
    child_pid: ?posix.pid_t,
    rows: u16,
    cols: u16,

    pub const Error = error{
        OpenPtyFailed,
        ForkFailed,
        ExecFailed,
        CloseFailed,
    };

    pub fn init(rows: u16, cols: u16) !Pty {
        // Open a new PTY pair
        var master_fd: posix.fd_t = undefined;
        var slave_fd: posix.fd_t = undefined;

        // Use openpty via libc
        const c = @cImport({
            @cInclude("pty.h");
            @cInclude("utmp.h");
        });

        var winsize = c.struct_winsize{
            .ws_row = rows,
            .ws_col = cols,
            .ws_xpixel = 0,
            .ws_ypixel = 0,
        };

        if (c.openpty(&master_fd, &slave_fd, null, null, &winsize) != 0) {
            return Error.OpenPtyFailed;
        }

        return Pty{
            .master_fd = master_fd,
            .slave_fd = slave_fd,
            .child_pid = null,
            .rows = rows,
            .cols = cols,
        };
    }

    pub fn deinit(self: *Pty) void {
        // Kill child process if running
        if (self.child_pid) |pid| {
            _ = posix.kill(pid, posix.SIG.TERM) catch {};
            _ = posix.waitpid(pid, 0);
        }

        posix.close(self.slave_fd);
        posix.close(self.master_fd);
    }

    /// Spawn a shell process
    pub fn spawn(self: *Pty, shell: ?[:0]const u8) !void {
        const shell_path = shell orelse getDefaultShell();

        const pid = try posix.fork();

        if (pid == 0) {
            // Child process
            childProcess(self.slave_fd, shell_path) catch {
                posix.exit(1);
            };
            unreachable;
        } else {
            // Parent process
            self.child_pid = pid;
            // Close slave fd in parent - child owns it now
            posix.close(self.slave_fd);
            self.slave_fd = -1;
        }
    }

    fn childProcess(slave_fd: posix.fd_t, shell_path: [:0]const u8) !void {
        // Create new session
        _ = posix.setsid() catch {};

        // Set controlling terminal
        _ = std.c.ioctl(slave_fd, std.os.linux.T.IOCSCTTY, @as(c_ulong, 0));

        // Duplicate slave fd to stdin, stdout, stderr
        _ = posix.dup2(slave_fd, 0) catch {};
        _ = posix.dup2(slave_fd, 1) catch {};
        _ = posix.dup2(slave_fd, 2) catch {};

        if (slave_fd > 2) {
            posix.close(slave_fd);
        }

        // Set up environment
        const env = [_:null]?[*:0]const u8{
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "LANG=en_US.UTF-8",
            "LC_ALL=en_US.UTF-8",
            "LC_CTYPE=en_US.UTF-8",
            std.c.getenv("HOME"),
            std.c.getenv("USER"),
            std.c.getenv("SHELL"),
            std.c.getenv("PATH"),
            std.c.getenv("TERMINFO"),
        };

        // Execute shell
        const argv = [_:null]?[*:0]const u8{shell_path.ptr};

        _ = posix.execvpeZ(shell_path.ptr, &argv, &env) catch {};
        posix.exit(127);
    }

    /// Read data from the PTY (non-blocking)
    pub fn read(self: *Pty, buffer: []u8) !usize {
        // Set non-blocking
        const O_NONBLOCK: u32 = 0o4000; // Linux O_NONBLOCK constant
        const flags = try posix.fcntl(self.master_fd, posix.F.GETFL, 0);
        _ = try posix.fcntl(self.master_fd, posix.F.SETFL, @as(u32, @intCast(flags)) | O_NONBLOCK);
        defer {
            _ = posix.fcntl(self.master_fd, posix.F.SETFL, @as(u32, @intCast(flags))) catch {};
        }

        return posix.read(self.master_fd, buffer) catch |err| {
            if (err == error.WouldBlock) return 0;
            return err;
        };
    }

    /// Write data to the PTY
    pub fn write(self: *Pty, data: []const u8) !usize {
        return posix.write(self.master_fd, data);
    }

    /// Resize the PTY
    pub fn resize(self: *Pty, rows: u16, cols: u16) !void {
        const c = @cImport({
            @cInclude("sys/ioctl.h");
        });

        var winsize = c.struct_winsize{
            .ws_row = rows,
            .ws_col = cols,
            .ws_xpixel = 0,
            .ws_ypixel = 0,
        };

        _ = std.c.ioctl(self.master_fd, c.TIOCSWINSZ, &winsize);
        self.rows = rows;
        self.cols = cols;
    }

    /// Check if child process is still running
    pub fn isAlive(self: *Pty) bool {
        if (self.child_pid) |pid| {
            const result = posix.waitpid(pid, posix.W.NOHANG);
            if (result.pid != 0) {
                // Child has exited
                self.child_pid = null;
                return false;
            }
            return true;
        }
        return false;
    }

    /// Get the file descriptor for polling
    pub fn getFd(self: *Pty) posix.fd_t {
        return self.master_fd;
    }
};

fn getDefaultShell() [:0]const u8 {
    // Try to get shell from environment
    if (std.c.getenv("SHELL")) |shell| {
        return std.mem.sliceTo(shell, 0);
    }
    // Fallback
    return "/bin/sh";
}
