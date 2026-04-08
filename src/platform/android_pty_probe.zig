const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

const has_real_probe = builtin.target.os.tag == .linux and builtin.target.abi == .android;

extern fn grantpt(fd: c_int) c_int;
extern fn unlockpt(fd: c_int) c_int;
extern fn ptsname_r(fd: c_int, buf: [*]u8, buflen: usize) c_int;

const probe_log_path = "/data/data/dev.zide.androidbootstrap/files/pty_probe.log";
const probe_shell: [:0]const u8 = "/system/bin/sh";
const master_path: [:0]const u8 = "/dev/ptmx";

const Probe = struct {
    master_fd: posix.fd_t,
    child_pid: ?posix.pid_t,

    fn deinit(self: *Probe) void {
        if (self.child_pid) |pid| {
            terminateProbeProcess(pid);
            waitForExitWithDeadline(pid);
            self.child_pid = null;
        }
        posix.close(self.master_fd);
    }
};

var probe: ?Probe = null;

pub const StartStatus = enum(i32) {
    none = 0,
    started = 1,
    unsupported = 2,
    delete_log_failed = 3,
    init_failed = 4,
    write_failed = 5,
    missing_pid = 6,
};

var last_start_status: StartStatus = .none;

pub fn logPath() []const u8 {
    return probe_log_path;
}

pub fn childPid() i64 {
    if (!hasRealProbe()) return -1;
    const active = probe orelse return -1;
    return active.child_pid orelse -1;
}

pub fn lastStartStatus() StartStatus {
    return last_start_status;
}

pub fn isAlive() bool {
    if (!hasRealProbe()) return false;
    if (probe) |*active| {
        if (pollExit(active)) {
            posix.close(active.master_fd);
            probe = null;
            return false;
        }
        return active.child_pid != null;
    }
    return false;
}

pub fn stop() void {
    if (!hasRealProbe()) return;
    var active = probe orelse return;
    active.deinit();
    probe = null;
}

pub fn start() !i64 {
    if (!hasRealProbe()) {
        last_start_status = .unsupported;
        return error.Unsupported;
    }
    if (probe != null) {
        if (isAlive()) return childPid();
        stop();
    }

    std.fs.deleteFileAbsolute(probe_log_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => {
            last_start_status = .delete_log_failed;
            return err;
        },
    };

    var next = initProbe() catch |err| {
        last_start_status = .init_failed;
        return err;
    };
    errdefer next.deinit();

    writeProbeCommand(next.master_fd) catch |err| {
        last_start_status = .write_failed;
        return err;
    };

    const pid = next.child_pid orelse {
        last_start_status = .missing_pid;
        return error.Unexpected;
    };

    probe = next;
    last_start_status = .started;
    return pid;
}

fn hasRealProbe() bool {
    return has_real_probe;
}

fn initProbe() !Probe {
    const master_fd = try posix.openZ(master_path, .{
        .ACCMODE = .RDWR,
        .CLOEXEC = true,
    }, 0);
    errdefer posix.close(master_fd);

    if (grantpt(@intCast(master_fd)) != 0) return error.OpenPtyFailed;
    if (unlockpt(@intCast(master_fd)) != 0) return error.OpenPtyFailed;

    var slave_name_buf: [128]u8 = undefined;
    if (ptsname_r(@intCast(master_fd), &slave_name_buf, slave_name_buf.len) != 0) {
        return error.OpenPtyFailed;
    }
    const slave_name: [*:0]const u8 = @ptrCast(&slave_name_buf);

    const pid = try posix.fork();
    if (pid == 0) {
        childProcess(master_fd, slave_name) catch posix.exit(127);
        unreachable;
    }

    return .{
        .master_fd = master_fd,
        .child_pid = pid,
    };
}

fn childProcess(master_fd: posix.fd_t, slave_name: [*:0]const u8) !void {
    posix.close(master_fd);
    _ = try posix.setsid();

    const slave_fd = try posix.openZ(slave_name, .{
        .ACCMODE = .RDWR,
    }, 0);
    defer if (slave_fd > 2) posix.close(slave_fd);

    try posix.dup2(slave_fd, 0);
    try posix.dup2(slave_fd, 1);
    try posix.dup2(slave_fd, 2);

    var command_buf: [768:0]u8 = undefined;
    const command = try std.fmt.bufPrintZ(
        &command_buf,
        "LOG='{s}'; : > \"$LOG\"; " ++
            "i=0; " ++
            "while :; do " ++
            "i=$((i+1)); " ++
            "printf 'heartbeat:%s:%s\\n' \"$i\" \"$(date +%s)\" >> \"$LOG\"; " ++
            "sleep 1; " ++
            "done",
        .{probe_log_path},
    );

    const argv = [_:null]?[*:0]const u8{
        probe_shell.ptr,
        "-c",
        command.ptr,
    };
    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(@constCast(std.c.environ));
    _ = posix.execvpeZ(probe_shell.ptr, &argv, envp) catch {};
    posix.exit(127);
}

fn writeProbeCommand(master_fd: posix.fd_t) !void {
    const command = "\n";
    _ = try posix.write(master_fd, command);
}

fn pollExit(active: *Probe) bool {
    const pid = active.child_pid orelse return true;
    const res = posix.waitpid(pid, posix.W.NOHANG);
    if (res.pid == 0) return false;
    active.child_pid = null;
    return true;
}

fn terminateProbeProcess(pid: posix.pid_t) void {
    const group_pid: posix.pid_t = -pid;
    posix.kill(group_pid, posix.SIG.TERM) catch {};
    posix.kill(pid, posix.SIG.TERM) catch {};
}

fn forceKillProbeProcess(pid: posix.pid_t) void {
    const group_pid: posix.pid_t = -pid;
    posix.kill(group_pid, posix.SIG.KILL) catch {};
    posix.kill(pid, posix.SIG.KILL) catch {};
}

fn waitForExitWithDeadline(pid: posix.pid_t) void {
    const deadline_ms: i64 = 50;
    const start_ms = std.time.milliTimestamp();
    while (true) {
        const res = posix.waitpid(pid, posix.W.NOHANG);
        if (res.pid != 0) return;
        if (std.time.milliTimestamp() - start_ms > deadline_ms) {
            forceKillProbeProcess(pid);
            _ = posix.waitpid(pid, 0);
            return;
        }
        std.Thread.sleep(2 * std.time.ns_per_ms);
    }
}

test "probe log path is stable" {
    try std.testing.expectEqualStrings(
        "/data/data/dev.zide.androidbootstrap/files/pty_probe.log",
        logPath(),
    );
}
