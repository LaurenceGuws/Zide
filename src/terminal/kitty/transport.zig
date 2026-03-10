const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../../app_logger.zig");
const image_decode = @import("../../ui/image_decode.zig");
const common = @import("common.zig");

const flate = std.compress.flate;
const posix = std.posix;

pub const KittyTransport = struct {
    pub fn loadPayload(self: anytype, control: *common.KittyControl, data: []const u8) ?[]u8 {
        if (control.medium == 'd') {
            return decodeBase64Payload(self, data);
        }
        if (control.more) return null;
        if (control.offset != 0) return null;

        const path_bytes = decodeBase64Payload(self, data) orelse return null;
        defer self.allocator.free(path_bytes);
        if (std.mem.indexOfScalar(u8, path_bytes, 0) != null) return null;
        const path = path_bytes;
        return switch (control.medium) {
            'f' => readFile(self, path, control.size, false),
            't' => readFile(self, path, control.size, true),
            's' => readSharedMemory(self, path, control.size),
            else => null,
        };
    }

    pub fn inflate(self: anytype, compressed: []const u8, expected_size: u32) ?[]u8 {
        const log = app_logger.logger("terminal.kitty");
        var stream = std.io.fixedBufferStream(compressed);
        var reader_buf: [8192]u8 = undefined;
        var adapter = stream.reader().adaptToNewApi(&reader_buf);
        var window: [flate.max_window_len]u8 = undefined;
        var decompressor = flate.Decompress.init(&adapter.new_interface, .zlib, &window);
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        const limit: usize = if (expected_size > 0) @intCast(expected_size) else common.kitty_max_bytes;
        var buf: [8192]u8 = undefined;
        while (true) {
            const n = decompressor.reader.readSliceShort(&buf) catch |err| {
                log.logf(.warning, "kitty inflate read failed err={s}", .{@errorName(err)});
                return null;
            };
            if (n == 0) break;
            if (out.items.len + n > limit) return null;
            _ = out.appendSlice(self.allocator, buf[0..n]) catch |err| {
                log.logf(.warning, "kitty inflate append failed bytes={d} err={s}", .{ n, @errorName(err) });
                return null;
            };
        }
        if (expected_size > 0 and out.items.len != expected_size) return null;
        return out.toOwnedSlice(self.allocator) catch |err| {
            log.logf(.warning, "kitty inflate ownership conversion failed err={s}", .{@errorName(err)});
            return null;
        };
    }

    pub fn accumulate(self: anytype, image_id: u32, control: *common.KittyControl, decoded: []u8) ?[]u8 {
        const log = app_logger.logger("terminal.kitty");
        const kitty = common.kittyState(self);
        var chunk = decoded;
        var compression = control.compression;
        if (kitty.partials.getEntry(image_id)) |entry| {
            if (control.quiet == 0) {
                control.quiet = entry.value_ptr.quiet;
            } else {
                entry.value_ptr.quiet = control.quiet;
            }
            if (compression == 0) {
                compression = entry.value_ptr.compression;
            }
        }
        if (compression == 'z') {
            const inflated = inflate(self, chunk, control.size) orelse {
                self.allocator.free(chunk);
                return null;
            };
            self.allocator.free(chunk);
            chunk = inflated;
        } else if (compression != 0) {
            self.allocator.free(chunk);
            return null;
        }

        if (control.more) {
            const entry = kitty.partials.getOrPut(image_id) catch |err| {
                log.logf(.warning, "kitty partial getOrPut failed id={d} err={s}", .{ image_id, @errorName(err) });
                return null;
            };
            if (!entry.found_existing) {
                const format = formatFor(control.format) orelse {
                    self.allocator.free(chunk);
                    return null;
                };
                const format_value: u32 = if (control.format != 0) control.format else 32;
                entry.value_ptr.* = common.KittyPartial{
                    .id = image_id,
                    .width = control.width,
                    .height = control.height,
                    .format = format,
                    .format_value = format_value,
                    .data = .empty,
                    .expected_size = control.size,
                    .received = 0,
                    .compression = compression,
                    .quiet = control.quiet,
                    .size_initialized = false,
                    .auto_place = control.action == 'T',
                    .placement_id = control.placement_id,
                    .cols = control.cols,
                    .rows = control.rows,
                    .z = control.z,
                    .cursor_movement = control.cursor_movement,
                    .virtual = control.virtual,
                    .parent_id = control.parent_id,
                    .child_id = control.child_id,
                    .parent_x = control.parent_x,
                    .parent_y = control.parent_y,
                };
            } else {
                if (control.quiet == 0) {
                    control.quiet = entry.value_ptr.quiet;
                } else {
                    entry.value_ptr.quiet = control.quiet;
                }
                if (entry.value_ptr.width == 0) entry.value_ptr.width = control.width;
                if (entry.value_ptr.height == 0) entry.value_ptr.height = control.height;
                if (entry.value_ptr.expected_size == 0) entry.value_ptr.expected_size = control.size;
                if (entry.value_ptr.format_value == 0 and control.format != 0) {
                    entry.value_ptr.format_value = control.format;
                }
                if (control.action == 'T') entry.value_ptr.auto_place = true;
                if (entry.value_ptr.placement_id == null and control.placement_id != null) entry.value_ptr.placement_id = control.placement_id;
                if (entry.value_ptr.cols == 0) entry.value_ptr.cols = control.cols;
                if (entry.value_ptr.rows == 0) entry.value_ptr.rows = control.rows;
                if (entry.value_ptr.z == 0) entry.value_ptr.z = control.z;
                if (entry.value_ptr.cursor_movement == 0) entry.value_ptr.cursor_movement = control.cursor_movement;
                if (entry.value_ptr.virtual == 0) entry.value_ptr.virtual = control.virtual;
                if (entry.value_ptr.parent_id == null and control.parent_id != null) entry.value_ptr.parent_id = control.parent_id;
                if (entry.value_ptr.child_id == null and control.child_id != null) entry.value_ptr.child_id = control.child_id;
                if (entry.value_ptr.parent_x == 0) entry.value_ptr.parent_x = control.parent_x;
                if (entry.value_ptr.parent_y == 0) entry.value_ptr.parent_y = control.parent_y;
            }
            if (!applyChunk(self, entry.value_ptr, control, chunk)) {
                self.allocator.free(chunk);
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            self.allocator.free(chunk);
            return null;
        }

        if (kitty.partials.getEntry(image_id)) |entry| {
            if (!applyChunk(self, entry.value_ptr, control, chunk)) {
                self.allocator.free(chunk);
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            self.allocator.free(chunk);
            if (entry.value_ptr.expected_size > 0 and entry.value_ptr.received != entry.value_ptr.expected_size) {
                entry.value_ptr.data.deinit(self.allocator);
                _ = kitty.partials.remove(image_id);
                return null;
            }
            const combined = entry.value_ptr.data.toOwnedSlice(self.allocator) catch |err| {
                log.logf(.warning, "kitty partial toOwnedSlice failed id={d} err={s}", .{ image_id, @errorName(err) });
                return null;
            };
            if (control.width == 0) control.width = entry.value_ptr.width;
            if (control.height == 0) control.height = entry.value_ptr.height;
            if (control.format == 0) {
                if (entry.value_ptr.format_value != 0) {
                    control.format = entry.value_ptr.format_value;
                } else {
                    control.format = switch (entry.value_ptr.format) {
                        .rgb => 24,
                        .png => 100,
                        .rgba => 32,
                    };
                }
            }
            if (entry.value_ptr.auto_place) {
                control.action = 'T';
                if (control.placement_id == null) control.placement_id = entry.value_ptr.placement_id;
                if (control.cols == 0) control.cols = entry.value_ptr.cols;
                if (control.rows == 0) control.rows = entry.value_ptr.rows;
                if (control.z == 0) control.z = entry.value_ptr.z;
                if (control.cursor_movement == 0) control.cursor_movement = entry.value_ptr.cursor_movement;
                if (control.virtual == 0) control.virtual = entry.value_ptr.virtual;
                if (control.parent_id == null) control.parent_id = entry.value_ptr.parent_id;
                if (control.child_id == null) control.child_id = entry.value_ptr.child_id;
                if (control.parent_x == 0) control.parent_x = entry.value_ptr.parent_x;
                if (control.parent_y == 0) control.parent_y = entry.value_ptr.parent_y;
            }
            entry.value_ptr.data.clearRetainingCapacity();
            _ = kitty.partials.remove(image_id);
            return combined;
        }

        if (control.size > 0) {
            if (control.size > common.kitty_max_bytes) {
                self.allocator.free(chunk);
                return null;
            }
            if (control.offset > 0) {
                self.allocator.free(chunk);
                return null;
            }
            if (chunk.len != control.size) {
                self.allocator.free(chunk);
                return null;
            }
        }
        if (chunk.len > common.kitty_max_bytes) {
            self.allocator.free(chunk);
            return null;
        }
        return chunk;
    }

    pub fn expectedDataBytes(control: common.KittyControl) ?usize {
        const format = formatFor(control.format) orelse return null;
        if (control.width == 0 or control.height == 0) return null;
        const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
        return switch (format) {
            .rgb => total_px * 3,
            .rgba => total_px * 4,
            else => null,
        };
    }

    pub fn buildImage(self: anytype, image_id: u32, control: common.KittyControl, data: []u8) common.KittyBuildError!common.KittyImage {
        const format = formatFor(control.format) orelse {
            self.allocator.free(data);
            return error.InvalidData;
        };
        switch (format) {
            .png => {
                const decoded = decodePng(self, data) catch |err| {
                    self.allocator.free(data);
                    return err;
                };
                self.allocator.free(data);
                return .{
                    .id = image_id,
                    .width = decoded.width,
                    .height = decoded.height,
                    .format = .rgba,
                    .data = decoded.data,
                    .version = 0,
                };
            },
            .rgb => return buildRawImage(self, image_id, control, data, 3, .rgb),
            .rgba => return buildRawImage(self, image_id, control, data, 4, .rgba),
        }
    }

    pub fn formatFor(value: u32) ?common.KittyImageFormat {
        return switch (value) {
            24 => .rgb,
            32 => .rgba,
            100 => .png,
            else => null,
        };
    }

    fn applyChunk(self: anytype, partial: *common.KittyPartial, control: *common.KittyControl, chunk: []const u8) bool {
        const log = app_logger.logger("terminal.kitty");
        const expected_size = if (partial.expected_size > 0) partial.expected_size else control.size;
        if (expected_size > 0 and expected_size > common.kitty_max_bytes) return false;
        if (expected_size > 0) {
            if (!partial.size_initialized) {
                partial.data.resize(self.allocator, expected_size) catch |err| {
                    log.logf(.warning, "kitty partial resize failed bytes={d} err={s}", .{ expected_size, @errorName(err) });
                    return false;
                };
                @memset(partial.data.items, 0);
                partial.size_initialized = true;
            }
            const offset = control.offset;
            if (offset > expected_size) return false;
            const end = offset + @as(u32, @intCast(chunk.len));
            if (end > expected_size) return false;
            std.mem.copyForwards(u8, partial.data.items[offset..end], chunk);
            partial.received = @max(partial.received, end);
            return true;
        }

        if (control.offset > 0) return false;
        if (partial.data.items.len + chunk.len > common.kitty_max_bytes) return false;
        _ = partial.data.appendSlice(self.allocator, chunk) catch |err| {
            log.logf(.warning, "kitty partial append failed bytes={d} err={s}", .{ chunk.len, @errorName(err) });
            return false;
        };
        partial.received = @intCast(partial.data.items.len);
        return true;
    }

    fn decodeBase64Payload(self: anytype, data: []const u8) ?[]u8 {
        const log = app_logger.logger("terminal.kitty");
        if (data.len == 0) {
            return self.allocator.alloc(u8, 0) catch {
                log.logf(.warning, "kitty decodeBase64 failed allocating empty payload", .{});
                return null;
            };
        }
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(data) catch {
            log.logf(.warning, "kitty decodeBase64 failed size calculation", .{});
            return null;
        };
        var decoded = std.ArrayList(u8).empty;
        var owned = false;
        defer if (!owned) decoded.deinit(self.allocator);
        decoded.resize(self.allocator, decoded_len) catch {
            log.logf(.warning, "kitty decodeBase64 failed buffer resize bytes={d}", .{decoded_len});
            return null;
        };
        _ = std.base64.standard.Decoder.decode(decoded.items, data) catch {
            log.logf(.warning, "kitty decodeBase64 failed decode", .{});
            return null;
        };
        const out = decoded.toOwnedSlice(self.allocator) catch {
            log.logf(.warning, "kitty decodeBase64 failed ownership conversion", .{});
            return null;
        };
        owned = true;
        return out;
    }

    fn readFile(self: anytype, path: []const u8, size: u32, is_temporary: bool) ?[]u8 {
        const log = app_logger.logger("terminal.kitty");
        if (is_temporary) {
            if (!std.mem.startsWith(u8, path, "/tmp/") and !std.mem.startsWith(u8, path, "/var/tmp/")) return null;
            if (std.mem.indexOf(u8, path, "tty-graphics-protocol") == null) return null;
        }
        var file = if (std.fs.path.isAbsolute(path))
            std.fs.openFileAbsolute(path, .{})
        else
            std.fs.cwd().openFile(path, .{});
        if (file) |*f| {
            defer f.close();
            defer if (is_temporary) {
                if (std.fs.path.isAbsolute(path)) {
                    std.fs.deleteFileAbsolute(path) catch |err| {
                        app_logger.logger("terminal.kitty").logf(.warning, "kitty temp file cleanup failed path={s} err={s}", .{ path, @errorName(err) });
                    };
                } else {
                    std.fs.cwd().deleteFile(path) catch |err| {
                        app_logger.logger("terminal.kitty").logf(.warning, "kitty temp file cleanup failed path={s} err={s}", .{ path, @errorName(err) });
                    };
                }
            };
            const stat = f.stat() catch |err| {
                log.logf(.warning, "kitty file stat failed path={s} err={s}", .{ path, @errorName(err) });
                return null;
            };
            const total: usize = @intCast(stat.size);
            const read_len: usize = if (size > 0) @min(@as(usize, size), total) else total;
            if (read_len > common.kitty_max_bytes) return null;
            const out = self.allocator.alloc(u8, read_len) catch {
                log.logf(.warning, "kitty file alloc failed path={s} bytes={d}", .{ path, read_len });
                return null;
            };
            const n = f.readAll(out) catch {
                self.allocator.free(out);
                log.logf(.warning, "kitty file read failed path={s}", .{path});
                return null;
            };
            if (n < read_len) {
                const trimmed = self.allocator.alloc(u8, n) catch {
                    self.allocator.free(out);
                    log.logf(.warning, "kitty file trim alloc failed path={s} bytes={d}", .{ path, n });
                    return null;
                };
                std.mem.copyForwards(u8, trimmed, out[0..n]);
                self.allocator.free(out);
                return trimmed;
            }
            return out;
        } else |_| {
            log.logf(.debug, "kitty file open failed path={s}", .{path});
            return null;
        }
    }

    fn readSharedMemory(self: anytype, name: []const u8, size: u32) ?[]u8 {
        const log = app_logger.logger("terminal.kitty");
        if (builtin.target.os.tag == .windows) return null;
        if (!builtin.link_libc) return null;
        if (builtin.target.os.tag == .windows) return null;
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&buf, "{s}", .{name}) catch {
            log.logf(.warning, "kitty shm name format failed name={s}", .{name});
            return null;
        };
        const fd = std.c.shm_open(name_z, @as(c_int, @bitCast(std.c.O{ .ACCMODE = .RDONLY })), 0);
        if (fd < 0) return null;
        defer _ = std.c.close(fd);
        defer _ = std.c.shm_unlink(name_z);
        const stat = posix.fstat(fd) catch |err| {
            log.logf(.warning, "kitty shm fstat failed name={s} err={s}", .{ name, @errorName(err) });
            return null;
        };
        if (stat.size <= 0) return null;
        const total: usize = @intCast(stat.size);
        const read_len: usize = if (size > 0) @min(@as(usize, size), total) else total;
        if (read_len > common.kitty_max_bytes) return null;
        const map = posix.mmap(null, read_len, std.c.PROT.READ, std.c.MAP{ .TYPE = .SHARED }, fd, 0) catch |err| {
            log.logf(.warning, "kitty shm mmap failed name={s} err={s}", .{ name, @errorName(err) });
            return null;
        };
        defer posix.munmap(map);
        const out = self.allocator.alloc(u8, read_len) catch {
            log.logf(.warning, "kitty shm alloc failed name={s} bytes={d}", .{ name, read_len });
            return null;
        };
        std.mem.copyForwards(u8, out, map[0..read_len]);
        return out;
    }

    fn decodePng(self: anytype, data: []const u8) common.KittyBuildError!struct { data: []u8, width: u32, height: u32 } {
        if (data.len == 0) return error.BadPng;
        const decoded = image_decode.decodePngRgba(self.allocator, data) catch return error.BadPng;
        const total_px: usize = @as(usize, decoded.width) * @as(usize, decoded.height);
        const expected_len = total_px * 4;
        if (expected_len > common.kitty_max_bytes) {
            self.allocator.free(decoded.data);
            return error.BadPng;
        }
        return .{ .data = decoded.data, .width = decoded.width, .height = decoded.height };
    }

    fn buildRawImage(self: anytype, image_id: u32, control: common.KittyControl, data: []u8, channels: usize, format: common.KittyImageFormat) common.KittyBuildError!common.KittyImage {
        if (control.width == 0 or control.height == 0) {
            self.allocator.free(data);
            return error.InvalidData;
        }
        const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
        const expected = total_px * channels;
        if (data.len < expected) {
            self.allocator.free(data);
            return error.InvalidData;
        }
        if (data.len != expected) {
            const trimmed = self.allocator.alloc(u8, expected) catch {
                self.allocator.free(data);
                return error.InvalidData;
            };
            std.mem.copyForwards(u8, trimmed, data[0..expected]);
            self.allocator.free(data);
            return .{ .id = image_id, .width = control.width, .height = control.height, .format = format, .data = trimmed, .version = 0 };
        }
        return .{ .id = image_id, .width = control.width, .height = control.height, .format = format, .data = data, .version = 0 };
    }
};
