const std = @import("std");
const builtin = @import("builtin");
const PtySize = @import("pty.zig").PtySize;

/// Windows ConPTY (Pseudo Console) implementation
pub const Pty = struct {
    hpc: ?*anyopaque, // HPCON
    input_read: ?*anyopaque, // HANDLE
    input_write: ?*anyopaque, // HANDLE
    output_read: ?*anyopaque, // HANDLE
    output_write: ?*anyopaque, // HANDLE
    process_info: ProcessInfo,
    rows: u16,
    cols: u16,

    const ProcessInfo = extern struct {
        hProcess: ?*anyopaque,
        hThread: ?*anyopaque,
        dwProcessId: u32,
        dwThreadId: u32,
    };

    pub const Error = error{
        CreatePipeFailed,
        CreatePseudoConsoleFailed,
        CreateProcessFailed,
        ResizeFailed,
        OutOfMemory,
    };

    const win32 = struct {
        // Windows API types and functions
        const HANDLE = *anyopaque;
        const HPCON = *anyopaque;
        const DWORD = u32;
        const BOOL = i32;
        const HRESULT = i32;
        const LPCWSTR = [*:0]const u16;
        const LPWSTR = [*:0]u16;

        const SECURITY_ATTRIBUTES = extern struct {
            nLength: DWORD,
            lpSecurityDescriptor: ?*anyopaque,
            bInheritHandle: BOOL,
        };

        const COORD = extern struct {
            X: i16,
            Y: i16,
        };

        const STARTUPINFOEXW = extern struct {
            StartupInfo: STARTUPINFOW,
            lpAttributeList: ?*anyopaque,
        };

        const STARTUPINFOW = extern struct {
            cb: DWORD,
            lpReserved: ?LPWSTR,
            lpDesktop: ?LPWSTR,
            lpTitle: ?LPWSTR,
            dwX: DWORD,
            dwY: DWORD,
            dwXSize: DWORD,
            dwYSize: DWORD,
            dwXCountChars: DWORD,
            dwYCountChars: DWORD,
            dwFillAttribute: DWORD,
            dwFlags: DWORD,
            wShowWindow: u16,
            cbReserved2: u16,
            lpReserved2: ?*u8,
            hStdInput: ?HANDLE,
            hStdOutput: ?HANDLE,
            hStdError: ?HANDLE,
        };

        const PROCESS_INFORMATION = extern struct {
            hProcess: ?HANDLE,
            hThread: ?HANDLE,
            dwProcessId: DWORD,
            dwThreadId: DWORD,
        };

        const EXTENDED_STARTUPINFO_PRESENT: DWORD = 0x00080000;
        const CREATE_UNICODE_ENVIRONMENT: DWORD = 0x00000400;
        const STARTF_USESTDHANDLES: DWORD = 0x00000100;
        const PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE: usize = 0x00020016;

        const HANDLE_FLAG_INHERIT: DWORD = 0x00000001;
        const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));

        extern "kernel32" fn CreatePipe(
            hReadPipe: *?HANDLE,
            hWritePipe: *?HANDLE,
            lpPipeAttributes: ?*SECURITY_ATTRIBUTES,
            nSize: DWORD,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn CreatePseudoConsole(
            size: COORD,
            hInput: HANDLE,
            hOutput: HANDLE,
            dwFlags: DWORD,
            phPC: *?HPCON,
        ) callconv(.winapi) HRESULT;

        extern "kernel32" fn ClosePseudoConsole(hPC: HPCON) callconv(.winapi) void;

        extern "kernel32" fn ResizePseudoConsole(hPC: HPCON, size: COORD) callconv(.winapi) HRESULT;

        extern "kernel32" fn InitializeProcThreadAttributeList(
            lpAttributeList: ?*anyopaque,
            dwAttributeCount: DWORD,
            dwFlags: DWORD,
            lpSize: *usize,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn UpdateProcThreadAttribute(
            lpAttributeList: *anyopaque,
            dwFlags: DWORD,
            Attribute: usize,
            lpValue: *anyopaque,
            cbSize: usize,
            lpPreviousValue: ?*anyopaque,
            lpReturnSize: ?*usize,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn DeleteProcThreadAttributeList(lpAttributeList: *anyopaque) callconv(.winapi) void;

        extern "kernel32" fn CreateProcessW(
            lpApplicationName: ?LPCWSTR,
            lpCommandLine: ?LPWSTR,
            lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
            lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
            bInheritHandles: BOOL,
            dwCreationFlags: DWORD,
            lpEnvironment: ?*anyopaque,
            lpCurrentDirectory: ?LPCWSTR,
            lpStartupInfo: *STARTUPINFOEXW,
            lpProcessInformation: *PROCESS_INFORMATION,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.winapi) BOOL;

        extern "kernel32" fn SetHandleInformation(hObject: HANDLE, dwMask: DWORD, dwFlags: DWORD) callconv(.winapi) BOOL;

        extern "kernel32" fn ReadFile(
            hFile: HANDLE,
            lpBuffer: [*]u8,
            nNumberOfBytesToRead: DWORD,
            lpNumberOfBytesRead: ?*DWORD,
            lpOverlapped: ?*anyopaque,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn WriteFile(
            hFile: HANDLE,
            lpBuffer: [*]const u8,
            nNumberOfBytesToWrite: DWORD,
            lpNumberOfBytesWritten: ?*DWORD,
            lpOverlapped: ?*anyopaque,
        ) callconv(.winapi) BOOL;

        extern "kernel32" fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) callconv(.winapi) DWORD;

        extern "kernel32" fn TerminateProcess(hProcess: HANDLE, uExitCode: u32) callconv(.winapi) BOOL;

        extern "kernel32" fn GetExitCodeProcess(hProcess: HANDLE, lpExitCode: *DWORD) callconv(.winapi) BOOL;

        extern "kernel32" fn PeekNamedPipe(
            hNamedPipe: HANDLE,
            lpBuffer: ?[*]u8,
            nBufferSize: DWORD,
            lpBytesRead: ?*DWORD,
            lpTotalBytesAvail: ?*DWORD,
            lpBytesLeftThisMessage: ?*DWORD,
        ) callconv(.winapi) BOOL;
    };

    const WAIT_TIMEOUT: win32.DWORD = 258;
    const STILL_ACTIVE: win32.DWORD = 259;

    pub fn init(allocator: std.mem.Allocator, size: PtySize, shell: ?[:0]const u8) !Pty {
        var pty = Pty{
            .hpc = null,
            .input_read = null,
            .input_write = null,
            .output_read = null,
            .output_write = null,
            .process_info = std.mem.zeroes(ProcessInfo),
            .rows = size.rows,
            .cols = size.cols,
        };

        // Create pipes for ConPTY
        var sa = win32.SECURITY_ATTRIBUTES{
            .nLength = @sizeOf(win32.SECURITY_ATTRIBUTES),
            .lpSecurityDescriptor = null,
            .bInheritHandle = 1,
        };

        // Pipe for PTY input (we write, PTY reads)
        if (win32.CreatePipe(&pty.input_read, &pty.input_write, &sa, 0) == 0) {
            return Error.CreatePipeFailed;
        }

        // Pipe for PTY output (PTY writes, we read)
        if (win32.CreatePipe(&pty.output_read, &pty.output_write, &sa, 0) == 0) {
            if (pty.input_read) |h| _ = win32.CloseHandle(h);
            if (pty.input_write) |h| _ = win32.CloseHandle(h);
            return Error.CreatePipeFailed;
        }

        // Create the Pseudo Console
        const coord = win32.COORD{
            .X = @intCast(size.cols),
            .Y = @intCast(size.rows),
        };

        const hr = win32.CreatePseudoConsole(
            coord,
            pty.input_read.?,
            pty.output_write.?,
            0,
            &pty.hpc,
        );

        if (hr < 0) {
            pty.cleanupHandles();
            return Error.CreatePseudoConsoleFailed;
        }

        // The pseudo console now owns these ends.
        if (pty.input_read) |h| {
            _ = win32.CloseHandle(h);
            pty.input_read = null;
        }
        if (pty.output_write) |h| {
            _ = win32.CloseHandle(h);
            pty.output_write = null;
        }

        try pty.spawn(allocator, shell);
        return pty;
    }

    pub fn deinit(self: *Pty) void {
        // Attempt a graceful shutdown first by closing the input stream and
        // waiting briefly. If the child does not exit, fall back to termination.
        if (self.input_write) |h| {
            _ = win32.CloseHandle(h);
            self.input_write = null;
        }

        if (self.process_info.hProcess) |h| {
            if (!self.waitForExit(200)) {
                _ = win32.TerminateProcess(h, 0);
                _ = self.waitForExit(200);
            }
            _ = win32.CloseHandle(h);
            self.process_info.hProcess = null;
        }
        if (self.process_info.hThread) |h| {
            _ = win32.CloseHandle(h);
            self.process_info.hThread = null;
        }

        // Close ConPTY
        if (self.hpc) |h| {
            win32.ClosePseudoConsole(h);
        }

        self.cleanupHandles();
    }

    fn waitForExit(self: *Pty, timeout_ms: win32.DWORD) bool {
        const h = self.process_info.hProcess orelse return true;
        const result = win32.WaitForSingleObject(h, timeout_ms);
        return result != WAIT_TIMEOUT;
    }

    fn cleanupHandles(self: *Pty) void {
        if (self.input_read) |h| _ = win32.CloseHandle(h);
        if (self.input_write) |h| _ = win32.CloseHandle(h);
        if (self.output_read) |h| _ = win32.CloseHandle(h);
        if (self.output_write) |h| _ = win32.CloseHandle(h);
    }

    /// Spawn a shell process (cmd.exe or PowerShell)
    pub fn spawn(self: *Pty, allocator: std.mem.Allocator, shell: ?[:0]const u8) !void {
        // Prepare startup info with ConPTY
        var attr_list_size: usize = 0;
        _ = win32.InitializeProcThreadAttributeList(null, 1, 0, &attr_list_size);

        // Allocate the required attribute list size.
        if (attr_list_size == 0) return Error.CreateProcessFailed;
        const attr_list_mem = allocator.alloc(u8, attr_list_size) catch return Error.OutOfMemory;
        defer allocator.free(attr_list_mem);
        const attr_list: *anyopaque = @ptrCast(attr_list_mem.ptr);

        if (win32.InitializeProcThreadAttributeList(attr_list, 1, 0, &attr_list_size) == 0) {
            return Error.CreateProcessFailed;
        }
        defer win32.DeleteProcThreadAttributeList(attr_list);

        if (win32.UpdateProcThreadAttribute(
            attr_list,
            0,
            win32.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
            self.hpc.?,
            @sizeOf(*anyopaque),
            null,
            null,
        ) == 0) {
            return Error.CreateProcessFailed;
        }

        var startup_info = std.mem.zeroes(win32.STARTUPINFOEXW);
        startup_info.StartupInfo.cb = @sizeOf(win32.STARTUPINFOEXW);
        startup_info.lpAttributeList = attr_list;

        // Ensure the child doesn't inherit redirected stdio handles from the parent.
        // This matches the approach in WezTerm/Alacritty and avoids a failure mode
        // where output bypasses the ConPTY stream.
        startup_info.StartupInfo.dwFlags |= win32.STARTF_USESTDHANDLES;
        startup_info.StartupInfo.hStdInput = win32.INVALID_HANDLE_VALUE;
        startup_info.StartupInfo.hStdOutput = win32.INVALID_HANDLE_VALUE;
        startup_info.StartupInfo.hStdError = win32.INVALID_HANDLE_VALUE;

        var proc_info: win32.PROCESS_INFORMATION = undefined;

        // Use cmd.exe as default shell.
        // If `shell` is provided, treat it as a command line string (path-only is fine).
        // Note: CreateProcessW may modify this buffer, so it must be mutable.
        var default_cmd_line = [_:0]u16{ 'c', 'm', 'd', '.', 'e', 'x', 'e', 0 };

        var cmd_line_owned: ?[:0]u16 = null;
        defer if (cmd_line_owned) |buf| allocator.free(buf);

        var cmd_line_ptr: win32.LPWSTR = @ptrCast(&default_cmd_line);
        if (shell) |raw_shell| {
            const shell_utf8 = std.mem.sliceTo(raw_shell, 0);

            // Basic quoting for paths with spaces.
            const needs_quotes = std.mem.indexOfScalar(u8, shell_utf8, ' ') != null;
            const already_quoted = shell_utf8.len >= 2 and shell_utf8[0] == '"' and shell_utf8[shell_utf8.len - 1] == '"';
            const cmd_utf8 = if (needs_quotes and !already_quoted)
                try std.fmt.allocPrint(allocator, "\"{s}\"", .{shell_utf8})
            else
                try allocator.dupe(u8, shell_utf8);
            defer allocator.free(cmd_utf8);

            cmd_line_owned = try utf8ToUtf16LeZAlloc(allocator, cmd_utf8);
            cmd_line_ptr = @ptrCast(cmd_line_owned.?.ptr);
        }

        if (win32.CreateProcessW(
            null,
            cmd_line_ptr,
            null,
            null,
            0,
            win32.EXTENDED_STARTUPINFO_PRESENT,
            null,
            null,
            &startup_info,
            &proc_info,
        ) == 0) {
            return Error.CreateProcessFailed;
        }

        self.process_info = .{
            .hProcess = proc_info.hProcess,
            .hThread = proc_info.hThread,
            .dwProcessId = proc_info.dwProcessId,
            .dwThreadId = proc_info.dwThreadId,
        };

        // Close the thread handle; we don't need it.
        if (self.process_info.hThread) |h| {
            _ = win32.CloseHandle(h);
            self.process_info.hThread = null;
        }
    }

    fn utf8ToUtf16LeZAlloc(allocator: std.mem.Allocator, s: []const u8) ![:0]u16 {
        const tmp = try std.unicode.utf8ToUtf16LeAlloc(allocator, s);
        defer allocator.free(tmp);
        var buf = try allocator.alloc(u16, tmp.len + 1);
        std.mem.copyForwards(u16, buf[0..tmp.len], tmp);
        buf[tmp.len] = 0;
        return buf[0..tmp.len :0];
    }

    /// Read data from the PTY (non-blocking)
    pub fn read(self: *Pty, buffer: []u8) !?usize {
        const handle = self.output_read orelse return null;

        // Check if data is available
        var available: win32.DWORD = 0;
        if (win32.PeekNamedPipe(handle, null, 0, null, &available, null) == 0) {
            return null;
        }
        if (available == 0) return null;

        var bytes_read: win32.DWORD = 0;
        const to_read: win32.DWORD = @min(@as(win32.DWORD, @intCast(buffer.len)), available);

        if (win32.ReadFile(handle, buffer.ptr, to_read, &bytes_read, null) == 0) {
            return null;
        }

        if (bytes_read == 0) return null;
        return bytes_read;
    }

    /// Write data to the PTY
    pub fn write(self: *Pty, data: []const u8) !usize {
        const handle = self.input_write orelse return 0;

        if (data.len == 0) return 0;
        var offset: usize = 0;
        while (offset < data.len) {
            var bytes_written: win32.DWORD = 0;
            const remaining: win32.DWORD = @intCast(data.len - offset);
            if (win32.WriteFile(handle, data.ptr + offset, remaining, &bytes_written, null) == 0) {
                break;
            }
            if (bytes_written == 0) break;
            offset += bytes_written;
        }

        return offset;
    }

    /// Resize the PTY
    pub fn resize(self: *Pty, size: PtySize) !void {
        if (self.hpc) |hpc| {
            const coord = win32.COORD{
                .X = @intCast(size.cols),
                .Y = @intCast(size.rows),
            };
            const hr = win32.ResizePseudoConsole(hpc, coord);
            if (hr < 0) {
                return Error.ResizeFailed;
            }
            self.rows = size.rows;
            self.cols = size.cols;
        }
    }

    /// Check if child process is still running
    pub fn isAlive(self: *Pty) bool {
        if (self.process_info.hProcess) |h| {
            const result = win32.WaitForSingleObject(h, 0);
            return result == WAIT_TIMEOUT;
        }
        return false;
    }

    pub fn pollExit(self: *Pty) !?i32 {
        const h = self.process_info.hProcess orelse return null;
        var code: win32.DWORD = 0;
        if (win32.GetExitCodeProcess(h, &code) == 0) {
            return null;
        }
        if (code == STILL_ACTIVE) return null;
        return @intCast(code);
    }

    pub fn hasData(self: *Pty) bool {
        const handle = self.output_read orelse return false;
        var available: win32.DWORD = 0;
        if (win32.PeekNamedPipe(handle, null, 0, null, &available, null) == 0) {
            return false;
        }
        return available > 0;
    }

    pub fn waitForData(self: *Pty, timeout_ms: i32) bool {
        if (self.hasData()) return true;
        if (timeout_ms <= 0) return false;
        std.time.sleep(@as(u64, @intCast(timeout_ms)) * std.time.ns_per_ms);
        return self.hasData();
    }

    /// Get the file handle for polling (not directly usable like Unix fd)
    pub fn getHandle(self: *Pty) ?*anyopaque {
        return self.output_read;
    }
};

test "windows conpty smoke" {
    if (builtin.target.os.tag != .windows) return;

    const allocator = std.testing.allocator;
    var pty = try Pty.init(allocator, .{ .rows = 24, .cols = 80, .cell_width = 8, .cell_height = 16 }, null);
    defer pty.deinit();

    // Give cmd.exe a moment to start and print its banner/prompt.
    var output = std.ArrayList(u8).empty;
    defer output.deinit(allocator);

    const marker = "ZIDE_PTY_OK";
    _ = try pty.write("echo " ++ marker ++ "\r\n");
    _ = try pty.write("exit\r\n");

    const start_ms = std.time.milliTimestamp();
    var buf: [4096]u8 = undefined;
    while (std.time.milliTimestamp() - start_ms < 3000) {
        if (!pty.waitForData(50)) continue;
        const n_opt = try pty.read(&buf);
        if (n_opt) |n| {
            if (n == 0) break;
            _ = try output.appendSlice(allocator, buf[0..n]);
            if (std.mem.indexOf(u8, output.items, marker) != null) return;
        }
    }

    std.debug.print("conpty output (truncated): {s}\n", .{output.items[0..@min(output.items.len, 1024)]});
    try std.testing.expect(false);
}
