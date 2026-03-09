const std = @import("std");
const snapshot_mod = @import("../core/snapshot.zig");
const app_logger = @import("../../app_logger.zig");
const builtin = @import("builtin");
const flate = std.compress.flate;
const posix = std.posix;
const image_decode = @import("../../ui/image_decode.zig");

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const KittyKV = struct {
    key: u8,
    value: u32,
};

pub const KittyPartial = struct {
    id: u32,
    width: u32,
    height: u32,
    format: KittyImageFormat,
    format_value: u32,
    data: std.ArrayList(u8),
    expected_size: u32,
    received: u32,
    compression: u8,
    quiet: u8,
    size_initialized: bool,
    auto_place: bool,
    placement_id: ?u32,
    cols: u32,
    rows: u32,
    z: i32,
    cursor_movement: u8,
    virtual: u32,
    parent_id: ?u32,
    child_id: ?u32,
    parent_x: i32,
    parent_y: i32,
};

pub const KittyControl = struct {
    action: u8 = 't',
    quiet: u8 = 0,
    delete_action: u8 = 'a',
    format: u32 = 0,
    medium: u8 = 'd',
    compression: u8 = 0,
    width: u32 = 0,
    height: u32 = 0,
    size: u32 = 0,
    offset: u32 = 0,
    image_id: ?u32 = null,
    image_number: ?u32 = null,
    placement_id: ?u32 = null,
    cols: u32 = 0,
    rows: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    x_offset: u32 = 0,
    y_offset: u32 = 0,
    z: i32 = 0,
    cursor_movement: u8 = 0,
    virtual: u32 = 0,
    parent_id: ?u32 = null,
    child_id: ?u32 = null,
    parent_x: i32 = 0,
    parent_y: i32 = 0,
    more: bool = false,
};

pub const KittyBuildError = error{
    InvalidData,
    BadPng,
};

const kitty_max_bytes: usize = 320 * 1024 * 1024;
const kitty_parent_max_depth: u8 = 10;

pub const KittyState = struct {
    images: std.ArrayList(KittyImage),
    placements: std.ArrayList(KittyPlacement),
    partials: std.AutoHashMap(u32, KittyPartial),
    next_id: u32,
    loading_image_id: ?u32,
    generation: u64,
    total_bytes: usize,
    scrollback_total: u64,
};

pub fn kittyState(self: anytype) *KittyState {
    return if (self.active == .alt) &self.kitty_alt else &self.kitty_primary;
}

pub fn kittyStateConst(self: anytype) *const KittyState {
    return if (self.active == .alt) &self.kitty_alt else &self.kitty_primary;
}

fn clearKittyLoading(kitty: *KittyState, image_id: u32) void {
    if (kitty.loading_image_id) |loading_id| {
        if (loading_id == image_id) {
            kitty.loading_image_id = null;
        }
    }
}

pub fn deinitKittyState(self: anytype, state: *KittyState) void {
    for (state.images.items) |image| {
        self.allocator.free(image.data);
    }
    state.images.deinit(self.allocator);
    state.placements.deinit(self.allocator);
    var partial_it = state.partials.iterator();
    while (partial_it.next()) |entry| {
        entry.value_ptr.data.deinit(self.allocator);
    }
    state.partials.deinit();
}

pub fn parseKittyGraphics(self: anytype, payload: []const u8) void {
    const log = app_logger.logger("terminal.kitty");
    var control = KittyControl{};
    var raw_kv = std.ArrayList(KittyKV).empty;
    defer raw_kv.deinit(self.allocator);
    const data = parseKittyControl(self.allocator, payload, &control, &raw_kv);
    if (!validateKittyControl(control)) {
        log.logf(.info, "kitty invalid command a={c} data_len={d}", .{ control.action, data.len });
        writeKittyResponse(self, control, resolveKittyImageId(control) orelse 0, false, "EINVAL");
        return;
    }
    if (control.action == 'd') {
        handleKittyDelete(self, control);
        return;
    }

    if (control.action == 'p') {
        handleKittyPlacementRequest(self, control);
        return;
    }

    if (control.action == 'q') {
        handleKittyQuery(self, control, data);
        return;
    }
    if (control.action != 't' and control.action != 'T') return;
    handleKittyUpload(self, control, data);
}

fn handleKittyDelete(self: anytype, control: KittyControl) void {
    if (!deleteKittyByAction(self, control)) {
        writeKittyResponse(self, control, resolveKittyImageId(control) orelse 0, false, "EINVAL");
    }
}

fn handleKittyPlacementRequest(self: anytype, control: KittyControl) void {
    const image_id = resolveKittyImageId(control) orelse return;
    if (placeKittyImage(self, image_id, control)) |err_msg| {
        writeKittyResponse(self, control, image_id, false, err_msg);
        return;
    }
    writeKittyResponse(self, control, image_id, true, "OK");
}

pub fn handleKittyQueryEarlyReply(self: anytype, control: KittyControl, data_len: usize) bool {
    const image_id = resolveKittyImageId(control) orelse return true;
    if (data_len == 0 and control.size == 0 and control.width == 0 and control.height == 0) {
        writeKittyResponse(self, control, image_id, true, "OK");
        return true;
    }
    return false;
}

pub fn handleKittyQueryPayloadPreflightReply(self: anytype, control: KittyControl, image_id: u32) bool {
    if (control.more or control.offset != 0) {
        writeKittyResponse(self, control, image_id, false, "EINVAL");
        return true;
    }
    return false;
}

pub fn handleKittyQueryPayloadLoadFailureReply(self: anytype, control: KittyControl, image_id: u32) void {
    writeKittyResponse(self, control, image_id, false, "EINVAL");
}

pub fn handleKittyQueryPayloadSizeReply(self: anytype, control: KittyControl, image_id: u32, chunk_len: usize) bool {
    const log = app_logger.logger("terminal.kitty");
    if (kittyExpectedDataBytes(control)) |expected| {
        if (chunk_len < expected) {
            var message = std.ArrayList(u8).empty;
            defer message.deinit(self.allocator);
            _ = message.writer(self.allocator).print(
                "ENODATA:Insufficient image data: {d} < {d}",
                .{ chunk_len, expected },
            ) catch |err| {
                log.logf(.warning, "kitty query payload size message format failed len={d} expected={d} err={s}", .{ chunk_len, expected, @errorName(err) });
                return false;
            };
            writeKittyResponse(self, control, image_id, false, message.items);
            return true;
        }
    }
    return false;
}

pub fn handleKittyQueryChunkBuildReply(
    self: anytype,
    control: KittyControl,
    image_id: u32,
    chunk_len: usize,
    builder_ctx: anytype,
    comptime build_fn: anytype,
) bool {
    if (handleKittyQueryPayloadSizeReply(self, control, image_id, chunk_len)) {
        return true;
    }
    build_fn(builder_ctx, self, image_id, control) catch |err| {
        writeKittyResponse(self, control, image_id, false, kittyQueryBuildErrorReplyMessage(err));
        return true;
    };
    writeKittyResponse(self, control, image_id, true, "OK");
    return true;
}

pub fn kittyQueryBuildErrorReplyMessage(err: KittyBuildError) []const u8 {
    return switch (err) {
        error.BadPng => "EBADPNG",
        else => "EINVAL",
    };
}

fn handleKittyQuery(self: anytype, control: KittyControl, data: []const u8) void {
    if (handleKittyQueryEarlyReply(self, control, data.len)) return;

    const image_id = resolveKittyImageId(control).?;
    var query_control = control;
    if (query_control.format == 0) {
        query_control.format = 32;
    }
    if (handleKittyQueryPayloadPreflightReply(self, query_control, image_id)) return;

    var chunk = loadKittyPayload(self, &query_control, data) orelse {
        handleKittyQueryPayloadLoadFailureReply(self, query_control, image_id);
        return;
    };
    chunk = inflateKittyQueryChunk(self, query_control, image_id, chunk) orelse return;
    defer self.allocator.free(chunk);

    if (handleKittyQueryPayloadSizeReply(self, query_control, image_id, chunk.len)) return;
    _ = handleKittyQueryChunkBuildReply(self, query_control, image_id, chunk.len, QueryBuilder{ .chunk = chunk }, QueryBuilder.run);
}

const QueryBuilder = struct {
    chunk: []u8,

    fn run(ctx: @This(), session: anytype, target_image_id: u32, ctl: KittyControl) KittyBuildError!void {
        const image = try buildKittyImage(session, target_image_id, ctl, ctx.chunk);
        session.allocator.free(image.data);
    }
};

fn inflateKittyQueryChunk(self: anytype, control: KittyControl, image_id: u32, chunk: []u8) ?[]u8 {
    if (control.compression == 'z') {
        const inflated = inflateKittyData(self, chunk, control.size) orelse {
            self.allocator.free(chunk);
            writeKittyResponse(self, control, image_id, false, "EINVAL");
            return null;
        };
        self.allocator.free(chunk);
        return inflated;
    }
    if (control.compression != 0) {
        self.allocator.free(chunk);
        writeKittyResponse(self, control, image_id, false, "EINVAL");
        return null;
    }
    return chunk;
}

fn handleKittyUpload(self: anytype, control: KittyControl, data: []const u8) void {
    const log = app_logger.logger("terminal.kitty");
    const upload = resolveKittyUpload(self, control) orelse return;
    var upload_control = upload.control;

    const decoded = loadKittyPayload(self, &upload_control, data) orelse {
        log.logf(.info, "kitty decode failed len={d}", .{data.len});
        clearKittyLoading(kittyState(self), upload.image_id);
        writeKittyResponse(self, upload_control, upload.image_id, false, "EINVAL");
        return;
    };

    const final_data = accumulateKittyData(self, upload.image_id, &upload_control, decoded) orelse {
        if (!upload_control.more) {
            clearKittyLoading(kittyState(self), upload.image_id);
        }
        return;
    };

    finishKittyUpload(self, upload_control, upload.image_id, final_data);
}

const UploadResolution = struct {
    image_id: u32,
    control: KittyControl,
};

fn resolveKittyUpload(self: anytype, control: KittyControl) ?UploadResolution {
    const kitty = kittyState(self);
    var upload_control = control;
    var image_id = resolveKittyImageId(upload_control);
    if (kitty.loading_image_id) |loading_id| {
        if (image_id) |explicit_id| {
            if (explicit_id != loading_id and upload_control.more) {
                kitty.loading_image_id = null;
                writeKittyResponse(self, upload_control, explicit_id, false, "EINVAL");
                return null;
            }
        } else {
            image_id = loading_id;
        }
    }
    if (image_id == null) {
        const id = kitty.next_id;
        kitty.next_id += 1;
        image_id = id;
    }
    const final_image_id = image_id.?;
    if (upload_control.more and kitty.loading_image_id == null) {
        kitty.loading_image_id = final_image_id;
    }
    if (upload_control.format == 0 and kitty.partials.getEntry(final_image_id) == null) {
        upload_control.format = 32;
    }
    return .{ .image_id = final_image_id, .control = upload_control };
}

fn finishKittyUpload(self: anytype, control: KittyControl, image_id: u32, final_data: []u8) void {
    const log = app_logger.logger("terminal.kitty");
    var upload_control = control;
    defer clearKittyLoading(kittyState(self), image_id);

    if (upload_control.format == 0) {
        upload_control.format = 32;
    }
    if (handleKittyUploadSizeReply(self, upload_control, image_id, final_data)) return;

    const image = buildKittyImage(self, image_id, upload_control, final_data) catch |err| {
        log.logf(.info, "kitty build failed id={d} format={d} data_len={d}", .{ image_id, upload_control.format, final_data.len });
        writeKittyResponse(self, upload_control, image_id, false, kittyQueryBuildErrorReplyMessage(err));
        return;
    };
    storeKittyImage(self, image);
    if (upload_control.action == 'T') {
        if (placeKittyImage(self, image_id, upload_control)) |err_msg| {
            writeKittyResponse(self, upload_control, image_id, false, err_msg);
            return;
        }
    }
    writeKittyResponse(self, upload_control, image_id, true, "OK");
}

fn handleKittyUploadSizeReply(self: anytype, control: KittyControl, image_id: u32, final_data: []u8) bool {
    if (kittyExpectedDataBytes(control)) |expected| {
        if (final_data.len < expected) {
            var message = std.ArrayList(u8).empty;
            defer message.deinit(self.allocator);
            _ = message.writer(self.allocator).print(
                "ENODATA:Insufficient image data: {d} < {d}",
                .{ final_data.len, expected },
            ) catch {
                self.allocator.free(final_data);
                return true;
            };
            self.allocator.free(final_data);
            writeKittyResponse(self, control, image_id, false, message.items);
            return true;
        }
    }
    return false;
}

fn parseKittyControl(
    allocator: std.mem.Allocator,
    payload: []const u8,
    control: *KittyControl,
    raw_kv: *std.ArrayList(KittyKV),
) []const u8 {
    var i: usize = 0;
    while (i < payload.len) {
        if (payload[i] == ';') {
            i += 1;
            break;
        }
        const key = payload[i];
        i += 1;
        if (i >= payload.len or payload[i] != '=') {
            while (i < payload.len and payload[i] != ',' and payload[i] != ';') : (i += 1) {}
            if (i < payload.len and payload[i] == ',') i += 1;
            if (i < payload.len and payload[i] == ';') {
                i += 1;
                break;
            }
            continue;
        }
        i += 1;
        const start_idx = i;
        while (i < payload.len and payload[i] != ',' and payload[i] != ';') : (i += 1) {}
        const value_slice = payload[start_idx..i];
        const parsed_unsigned = parseKittyValue(value_slice);
        const parsed_signed = parseKittySigned(value_slice);
        if (parsed_unsigned != null or parsed_signed != null) {
            const handled = switch (key) {
                'a' => blk: {
                    if (parsed_unsigned) |value| control.action = @intCast(value);
                    break :blk true;
                },
                'q' => blk: {
                    if (parsed_unsigned) |value| control.quiet = @intCast(value);
                    break :blk true;
                },
                'd' => blk: {
                    if (parsed_unsigned) |value| control.delete_action = @intCast(value);
                    break :blk true;
                },
                'f' => blk: {
                    if (parsed_unsigned) |value| control.format = value;
                    break :blk true;
                },
                't' => blk: {
                    if (parsed_unsigned) |value| control.medium = @intCast(value);
                    break :blk true;
                },
                'o' => blk: {
                    if (parsed_unsigned) |value| control.compression = @intCast(value);
                    break :blk true;
                },
                's' => blk: {
                    if (parsed_unsigned) |value| control.width = value;
                    break :blk true;
                },
                'v' => blk: {
                    if (parsed_unsigned) |value| control.height = value;
                    break :blk true;
                },
                'S' => blk: {
                    if (parsed_unsigned) |value| control.size = value;
                    break :blk true;
                },
                'O' => blk: {
                    if (parsed_unsigned) |value| control.offset = value;
                    break :blk true;
                },
                'i' => blk: {
                    if (parsed_unsigned) |value| control.image_id = value;
                    break :blk true;
                },
                'I' => blk: {
                    if (parsed_unsigned) |value| control.image_number = value;
                    break :blk true;
                },
                'p' => blk: {
                    if (parsed_unsigned) |value| control.placement_id = value;
                    break :blk true;
                },
                'c' => blk: {
                    if (parsed_unsigned) |value| control.cols = value;
                    break :blk true;
                },
                'r' => blk: {
                    if (parsed_unsigned) |value| control.rows = value;
                    break :blk true;
                },
                'x' => blk: {
                    if (parsed_unsigned) |value| control.x = value;
                    break :blk true;
                },
                'y' => blk: {
                    if (parsed_unsigned) |value| control.y = value;
                    break :blk true;
                },
                'w' => blk: {
                    if (parsed_unsigned) |value| control.width = value;
                    break :blk true;
                },
                'h' => blk: {
                    if (parsed_unsigned) |value| control.height = value;
                    break :blk true;
                },
                'X' => blk: {
                    if (parsed_unsigned) |value| control.x_offset = value;
                    break :blk true;
                },
                'Y' => blk: {
                    if (parsed_unsigned) |value| control.y_offset = value;
                    break :blk true;
                },
                'z' => blk: {
                    if (parsed_signed) |value| control.z = value;
                    break :blk true;
                },
                'C' => blk: {
                    if (parsed_unsigned) |value| control.cursor_movement = @intCast(value);
                    break :blk true;
                },
                'U' => blk: {
                    if (parsed_unsigned) |value| control.virtual = value;
                    break :blk true;
                },
                'P' => blk: {
                    if (parsed_unsigned) |value| control.parent_id = value;
                    break :blk true;
                },
                'Q' => blk: {
                    if (parsed_unsigned) |value| control.child_id = value;
                    break :blk true;
                },
                'H' => blk: {
                    if (parsed_signed) |value| control.parent_x = value;
                    break :blk true;
                },
                'V' => blk: {
                    if (parsed_signed) |value| control.parent_y = value;
                    break :blk true;
                },
                'm' => blk: {
                    if (parsed_unsigned) |value| control.more = value != 0;
                    break :blk true;
                },
                else => false,
            };
            if (!handled) {
                if (parsed_unsigned) |value| {
                    raw_kv.append(allocator, .{ .key = key, .value = value }) catch |err| {
                        app_logger.logger("terminal.kitty").logf(.warning, "kitty control raw kv append failed key={c} err={s}", .{ key, @errorName(err) });
                    };
                }
            }
        }
        if (i < payload.len and payload[i] == ',') {
            i += 1;
            continue;
        }
        if (i < payload.len and payload[i] == ';') {
            i += 1;
            break;
        }
    }
    return payload[i..];
}

fn parseKittyValue(text: []const u8) ?u32 {
    const log = app_logger.logger("terminal.kitty");
    if (text.len == 0) return null;
    if (text.len == 1 and (text[0] < '0' or text[0] > '9')) {
        return @intCast(text[0]);
    }
    return std.fmt.parseUnsigned(u32, text, 10) catch {
        log.logf(.debug, "kitty parse unsigned failed text={s}", .{text});
        return null;
    };
}

fn parseKittySigned(text: []const u8) ?i32 {
    const log = app_logger.logger("terminal.kitty");
    if (text.len == 0) return null;
    return std.fmt.parseInt(i32, text, 10) catch {
        log.logf(.debug, "kitty parse signed failed text={s}", .{text});
        return null;
    };
}

fn resolveKittyImageId(control: KittyControl) ?u32 {
    if (control.image_id) |id| return id;
    if (control.image_number) |id| return id;
    return null;
}

fn validateKittyControl(control: KittyControl) bool {
    switch (control.action) {
        't', 'T', 'p', 'd', 'q' => {},
        else => return false,
    }

    if (control.quiet > 2) return false;
    if (control.image_id != null and control.image_number != null) return false;

    if (control.action == 't' or control.action == 'T') {
        if (control.format != 0 and kittyFormatFor(control.format) == null) return false;
        if (control.medium != 'd' and control.medium != 'f' and control.medium != 't' and control.medium != 's') return false;
        if (control.compression != 0 and control.compression != 'z') return false;
    }

    if (control.action == 'p' or control.action == 'T') {
        if (control.image_id == null and control.image_number == null) return false;
        if (control.virtual != 0 and (control.parent_id != null or control.child_id != null or control.parent_x != 0 or control.parent_y != 0)) {
            return false;
        }
        if ((control.parent_id != null) != (control.child_id != null)) return false;
    }

    return true;
}

fn decodeBase64(self: anytype, data: []const u8) ?[]u8 {
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

fn loadKittyPayload(self: anytype, control: *KittyControl, data: []const u8) ?[]u8 {
    if (control.medium == 'd') {
        return decodeBase64(self, data);
    }
    if (control.more) return null;
    if (control.offset != 0) return null;

    const path_bytes = decodeBase64(self, data) orelse return null;
    defer self.allocator.free(path_bytes);
    if (std.mem.indexOfScalar(u8, path_bytes, 0) != null) return null;
    const path = path_bytes;
    return switch (control.medium) {
        'f' => readKittyFile(self, path, control.size, false),
        't' => readKittyFile(self, path, control.size, true),
        's' => readKittySharedMemory(self, path, control.size),
        else => null,
    };
}

fn readKittyFile(self: anytype, path: []const u8, size: u32, is_temporary: bool) ?[]u8 {
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
        if (read_len > kitty_max_bytes) return null;
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

fn readKittySharedMemory(self: anytype, name: []const u8, size: u32) ?[]u8 {
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
    if (read_len > kitty_max_bytes) return null;
    const map = posix.mmap(
        null,
        read_len,
        std.c.PROT.READ,
        std.c.MAP{ .TYPE = .SHARED },
        fd,
        0,
    ) catch |err| {
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

fn accumulateKittyData(self: anytype, image_id: u32, control: *KittyControl, decoded: []u8) ?[]u8 {
    const log = app_logger.logger("terminal.kitty");
    const kitty = kittyState(self);
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
        const inflated = inflateKittyData(self, chunk, control.size) orelse {
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
            const format = kittyFormatFor(control.format) orelse {
                self.allocator.free(chunk);
                return null;
            };
            const format_value: u32 = if (control.format != 0) control.format else 32;
            entry.value_ptr.* = KittyPartial{
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
            if (entry.value_ptr.placement_id == null and control.placement_id != null) {
                entry.value_ptr.placement_id = control.placement_id;
            }
            if (entry.value_ptr.cols == 0) entry.value_ptr.cols = control.cols;
            if (entry.value_ptr.rows == 0) entry.value_ptr.rows = control.rows;
            if (entry.value_ptr.z == 0) entry.value_ptr.z = control.z;
            if (entry.value_ptr.cursor_movement == 0) entry.value_ptr.cursor_movement = control.cursor_movement;
            if (entry.value_ptr.virtual == 0) entry.value_ptr.virtual = control.virtual;
            if (entry.value_ptr.parent_id == null and control.parent_id != null) {
                entry.value_ptr.parent_id = control.parent_id;
            }
            if (entry.value_ptr.child_id == null and control.child_id != null) {
                entry.value_ptr.child_id = control.child_id;
            }
            if (entry.value_ptr.parent_x == 0) entry.value_ptr.parent_x = control.parent_x;
            if (entry.value_ptr.parent_y == 0) entry.value_ptr.parent_y = control.parent_y;
        }
        if (!applyKittyChunk(self, entry.value_ptr, control, chunk)) {
            self.allocator.free(chunk);
            entry.value_ptr.data.deinit(self.allocator);
            _ = kitty.partials.remove(image_id);
            return null;
        }
        self.allocator.free(chunk);
        return null;
    }

    if (kitty.partials.getEntry(image_id)) |entry| {
        if (!applyKittyChunk(self, entry.value_ptr, control, chunk)) {
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
        if (control.size > kitty_max_bytes) {
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
    if (chunk.len > kitty_max_bytes) {
        self.allocator.free(chunk);
        return null;
    }
    return chunk;
}

fn applyKittyChunk(self: anytype, partial: *KittyPartial, control: *KittyControl, chunk: []const u8) bool {
    const log = app_logger.logger("terminal.kitty");
    const expected_size = if (partial.expected_size > 0) partial.expected_size else control.size;
    if (expected_size > 0 and expected_size > kitty_max_bytes) return false;
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
    if (partial.data.items.len + chunk.len > kitty_max_bytes) return false;
    _ = partial.data.appendSlice(self.allocator, chunk) catch |err| {
        log.logf(.warning, "kitty partial append failed bytes={d} err={s}", .{ chunk.len, @errorName(err) });
        return false;
    };
    partial.received = @intCast(partial.data.items.len);
    return true;
}

fn inflateKittyData(self: anytype, compressed: []const u8, expected_size: u32) ?[]u8 {
    const log = app_logger.logger("terminal.kitty");
    var stream = std.io.fixedBufferStream(compressed);
    var reader_buf: [8192]u8 = undefined;
    var adapter = stream.reader().adaptToNewApi(&reader_buf);
    var window: [flate.max_window_len]u8 = undefined;
    var decompressor = flate.Decompress.init(&adapter.new_interface, .zlib, &window);
    var out = std.ArrayList(u8).empty;
    defer out.deinit(self.allocator);
    const limit: usize = if (expected_size > 0) @intCast(expected_size) else kitty_max_bytes;
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

fn kittyFormatFor(value: u32) ?KittyImageFormat {
    return switch (value) {
        24 => .rgb,
        32 => .rgba,
        100 => .png,
        else => null,
    };
}

fn kittyExpectedDataBytes(control: KittyControl) ?usize {
    const format = kittyFormatFor(control.format) orelse return null;
    if (control.width == 0 or control.height == 0) return null;
    const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
    return switch (format) {
        .rgb => total_px * 3,
        .rgba => total_px * 4,
        else => null,
    };
}

fn findKittyImageById(images: []const KittyImage, image_id: u32) ?KittyImage {
    for (images) |image| {
        if (image.id == image_id) return image;
    }
    return null;
}

fn buildKittyImage(self: anytype, image_id: u32, control: KittyControl, data: []u8) KittyBuildError!KittyImage {
    const format = kittyFormatFor(control.format) orelse {
        self.allocator.free(data);
        return error.InvalidData;
    };
    switch (format) {
        .png => {
            const decoded = decodeKittyPng(self, data) catch |err| {
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
        .rgb => {
            if (control.width == 0 or control.height == 0) {
                self.allocator.free(data);
                return error.InvalidData;
            }
            const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
            const expected = total_px * 3;
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
                return .{
                    .id = image_id,
                    .width = control.width,
                    .height = control.height,
                    .format = .rgb,
                    .data = trimmed,
                    .version = 0,
                };
            }
            return .{
                .id = image_id,
                .width = control.width,
                .height = control.height,
                .format = .rgb,
                .data = data,
                .version = 0,
            };
        },
        .rgba => {
            if (control.width == 0 or control.height == 0) {
                self.allocator.free(data);
                return error.InvalidData;
            }
            const total_px: usize = @as(usize, control.width) * @as(usize, control.height);
            const expected = total_px * 4;
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
                return .{
                    .id = image_id,
                    .width = control.width,
                    .height = control.height,
                    .format = .rgba,
                    .data = trimmed,
                    .version = 0,
                };
            }
            return .{
                .id = image_id,
                .width = control.width,
                .height = control.height,
                .format = .rgba,
                .data = data,
                .version = 0,
            };
        },
    }
}

fn decodeKittyPng(self: anytype, data: []const u8) KittyBuildError!struct { data: []u8, width: u32, height: u32 } {
    if (data.len == 0) return error.BadPng;
    const decoded = image_decode.decodePngRgba(self.allocator, data) catch return error.BadPng;
    const total_px: usize = @as(usize, decoded.width) * @as(usize, decoded.height);
    const expected_len = total_px * 4;
    if (expected_len > kitty_max_bytes) {
        self.allocator.free(decoded.data);
        return error.BadPng;
    }
    return .{ .data = decoded.data, .width = decoded.width, .height = decoded.height };
}

fn kittyImageHasPlacement(self: anytype, image_id: u32) bool {
    const kitty = kittyStateConst(self);
    for (kitty.placements.items) |placement| {
        if (placement.image_id == image_id) return true;
    }
    return false;
}

fn kittyVisibleTop(self: anytype) u64 {
    if (self.active == .alt) return 0;
    const kitty = kittyStateConst(self);
    const count = self.history.scrollbackCount();
    if (kitty.scrollback_total < count) return 0;
    return kitty.scrollback_total - count;
}

const KittyDirtyRegion = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

const KittyDirtyPlacement = union(enum) {
    none,
    partial: KittyDirtyRegion,
    full,
};

fn kittyPlacementDirtyRegion(
    image: ?KittyImage,
    placement: KittyPlacement,
    screen_rows: usize,
    screen_cols: usize,
    cell_width: u16,
    cell_height: u16,
) KittyDirtyPlacement {
    if (screen_rows == 0 or screen_cols == 0) return .none;

    const start_row = @as(usize, placement.row);
    const start_col = @as(usize, placement.col);
    if (start_row >= screen_rows or start_col >= screen_cols) return .none;

    const col_span = if (placement.cols > 0)
        @as(usize, placement.cols)
    else blk: {
        const kitty_image = image orelse return .full;
        if (cell_width == 0 or kitty_image.width == 0) return .full;
        break :blk @as(usize, std.math.divCeil(u32, kitty_image.width, cell_width) catch return .full);
    };
    const row_span = if (placement.rows > 0)
        @as(usize, placement.rows)
    else blk: {
        const kitty_image = image orelse return .full;
        if (cell_height == 0 or kitty_image.height == 0) return .full;
        break :blk @as(usize, std.math.divCeil(u32, kitty_image.height, cell_height) catch return .full);
    };

    const dirty_cols = @max(@as(usize, 1), col_span);
    const dirty_rows = @max(@as(usize, 1), row_span);
    return .{
        .partial = .{
            .start_row = start_row,
            .end_row = @min(screen_rows - 1, start_row + dirty_rows - 1),
            .start_col = start_col,
            .end_col = @min(screen_cols - 1, start_col + dirty_cols - 1),
        },
    };
}

fn markKittyPlacementDirty(self: anytype, placement: KittyPlacement, src: std.builtin.SourceLocation) void {
    const screen = self.activeScreen();
    const kitty = kittyStateConst(self);
    const image = findKittyImageById(kitty.images.items, placement.image_id);
    switch (kittyPlacementDirtyRegion(
        image,
        placement,
        screen.grid.rows,
        screen.grid.cols,
        self.cell_width,
        self.cell_height,
    )) {
        .none => {},
        .partial => |region| screen.grid.markDirtyRange(region.start_row, region.end_row, region.start_col, region.end_col),
        .full => screen.grid.markDirtyAllWithReason(.kitty_graphics_changed, src),
    }
}

fn markKittyImagePlacementsDirty(self: anytype, image_id: u32, src: std.builtin.SourceLocation) void {
    const kitty = kittyStateConst(self);
    for (kitty.placements.items) |placement| {
        if (placement.image_id == image_id or placement.parent_image_id == image_id) {
            markKittyPlacementDirty(self, placement, src);
        }
    }
}

pub fn updateKittyPlacementsForScroll(self: anytype) void {
    const kitty = kittyState(self);
    if (kitty.placements.items.len == 0) return;
    const screen = self.activeScreenConst();
    const rows = @as(u64, screen.grid.rows);
    const top = kittyVisibleTop(self);
    const max_row = top + rows;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.anchor_row < top or placement.anchor_row >= max_row) {
            markKittyPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const new_row: u64 = placement.anchor_row - top;
        if (placement.row != @as(u16, @intCast(new_row))) {
            const old_placement = placement.*;
            placement.row = @as(u16, @intCast(new_row));
            markKittyPlacementDirty(self, old_placement, @src());
            markKittyPlacementDirty(self, placement.*, @src());
            changed = true;
        }
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

pub fn shiftKittyPlacementsUp(self: anytype, top: usize, bottom: usize, count: usize) void {
    const kitty = kittyState(self);
    if (count == 0 or kitty.placements.items.len == 0) return;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.row < top or placement.row > bottom) {
            idx += 1;
            continue;
        }
        if (placement.row < top + count) {
            markKittyPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const old_placement = placement.*;
        placement.row = @intCast(placement.row - count);
        if (placement.anchor_row >= count) {
            placement.anchor_row -= count;
        }
        markKittyPlacementDirty(self, old_placement, @src());
        markKittyPlacementDirty(self, placement.*, @src());
        changed = true;
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

pub fn shiftKittyPlacementsDown(self: anytype, top: usize, bottom: usize, count: usize) void {
    const kitty = kittyState(self);
    if (count == 0 or kitty.placements.items.len == 0) return;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.row < top or placement.row > bottom) {
            idx += 1;
            continue;
        }
        if (placement.row + count > bottom) {
            markKittyPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const old_placement = placement.*;
        placement.row = @intCast(placement.row + count);
        placement.anchor_row += count;
        markKittyPlacementDirty(self, old_placement, @src());
        markKittyPlacementDirty(self, placement.*, @src());
        changed = true;
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

fn ensureKittyCapacity(self: anytype, additional: usize) bool {
    const kitty = kittyState(self);
    if (additional == 0) return true;
    while (kitty.total_bytes + additional > kitty_max_bytes) {
        if (!evictKittyImage(self, true)) {
            if (!evictKittyImage(self, false)) return false;
        }
    }
    return true;
}

fn dropKittyPlacementsForImage(self: anytype, image_id: u32, include_children: bool) void {
    const kitty = kittyState(self);
    markKittyImagePlacementsDirty(self, image_id, @src());
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = kitty.placements.items[idx];
        if (placement.image_id == image_id or (include_children and placement.parent_image_id == image_id)) {
            _ = kitty.placements.swapRemove(idx);
        } else {
            idx += 1;
        }
    }
}

fn dropKittyPartial(self: anytype, image_id: u32) void {
    const kitty = kittyState(self);
    if (kitty.partials.getEntry(image_id)) |entry| {
        entry.value_ptr.data.deinit(self.allocator);
        _ = kitty.partials.remove(image_id);
    }
}

fn removeStoredKittyImageAt(self: anytype, idx: usize, include_children: bool) void {
    const kitty = kittyState(self);
    const image = kitty.images.items[idx];
    dropKittyPlacementsForImage(self, image.id, include_children);
    self.allocator.free(image.data);
    kitty.total_bytes -= image.data.len;
    _ = kitty.images.swapRemove(idx);
    dropKittyPartial(self, image.id);
}

fn evictKittyImage(self: anytype, prefer_unplaced: bool) bool {
    const kitty = kittyState(self);
    if (kitty.images.items.len == 0) return false;
    var best_idx: ?usize = null;
    var best_version: u64 = std.math.maxInt(u64);
    for (kitty.images.items, 0..) |image, idx| {
        if (prefer_unplaced and kittyImageHasPlacement(self, image.id)) continue;
        if (image.version < best_version) {
            best_version = image.version;
            best_idx = idx;
        }
    }
    if (best_idx == null) return false;
    removeStoredKittyImageAt(self, best_idx.?, false);
    kitty.generation += 1;
    return true;
}

fn storeKittyImage(self: anytype, image: KittyImage) void {
    const log = app_logger.logger("terminal.kitty");
    const kitty = kittyState(self);
    kitty.generation += 1;
    const version = kitty.generation;
    var idx: usize = 0;
    while (idx < kitty.images.items.len) : (idx += 1) {
        if (kitty.images.items[idx].id == image.id) {
            const old_len = kitty.images.items[idx].data.len;
            dropKittyPlacementsForImage(self, image.id, false);
            if (image.data.len > kitty_max_bytes) {
                self.allocator.free(image.data);
                return;
            }
            const extra = if (image.data.len > old_len) image.data.len - old_len else 0;
            if (!ensureKittyCapacity(self, extra)) {
                self.allocator.free(image.data);
                return;
            }
            self.allocator.free(kitty.images.items[idx].data);
            kitty.total_bytes -= old_len;
            kitty.images.items[idx] = image;
            kitty.images.items[idx].version = version;
            kitty.total_bytes += image.data.len;
            log.logf(.info, "kitty image updated id={d} format={s} bytes={d}", .{ image.id, @tagName(image.format), image.data.len });
            return;
        }
    }
    if (image.data.len > kitty_max_bytes) {
        self.allocator.free(image.data);
        return;
    }
    if (!ensureKittyCapacity(self, image.data.len)) {
        self.allocator.free(image.data);
        return;
    }
    var stored = image;
    stored.version = version;
    kitty.images.append(self.allocator, stored) catch |err| {
        self.allocator.free(stored.data);
        log.logf(.warning, "kitty image store failed id={d} err={s}", .{ stored.id, @errorName(err) });
        return;
    };
    kitty.total_bytes += stored.data.len;
    log.logf(.info, "kitty image stored id={d} format={s} bytes={d}", .{ stored.id, @tagName(stored.format), stored.data.len });
}

fn placeKittyImage(self: anytype, image_id: u32, control: KittyControl) ?[]const u8 {
    const log = app_logger.logger("terminal.kitty");
    const kitty = kittyState(self);
    const screen = self.activeScreen();
    if (screen.grid.rows == 0 or screen.grid.cols == 0) return "EINVAL";
    if (findKittyImageById(kitty.images.items, image_id) == null) return "ENOENT";
    const base_row = @min(@as(u16, @intCast(screen.cursor.row)), screen.grid.rows - 1);
    const base_col = @min(@as(u16, @intCast(screen.cursor.col)), screen.grid.cols - 1);
    var row = base_row;
    var col = base_col;
    var parent_image_id: u32 = 0;
    var parent_placement_id: u32 = 0;
    if (control.parent_id != null or control.child_id != null) {
        const parent_id = control.parent_id orelse return "ENOPARENT";
        const parent_pid = control.child_id orelse return "ENOPARENT";
        const placement_id = control.placement_id orelse 0;
        if (placement_id != 0 and parent_id == image_id and parent_pid == placement_id) return "EINVAL";
        parent_image_id = parent_id;
        parent_placement_id = parent_pid;
        const parent = findKittyPlacement(self, parent_id, parent_pid) orelse return "ENOPARENT";
        if (placement_id != 0) {
            const chain_check = kittyValidateParentChain(self, parent, image_id, placement_id);
            if (chain_check) |err_msg| return err_msg;
        } else {
            if (kittyParentChainTooDeep(self, parent)) return "ETOODEEP";
        }
        const offset_x: i32 = control.parent_x;
        const offset_y: i32 = control.parent_y;
        const parent_row: i32 = @intCast(parent.row);
        const parent_col: i32 = @intCast(parent.col);
        const new_row = parent_row + offset_y;
        const new_col = parent_col + offset_x;
        if (new_row < 0 or new_col < 0) return "EINVAL";
        row = @as(u16, @intCast(new_row));
        col = @as(u16, @intCast(new_col));
        if (row >= screen.grid.rows or col >= screen.grid.cols) return "EINVAL";
    }
    const visible_top = kittyVisibleTop(self);
    const placement_id = control.placement_id orelse 0;
    const placement = KittyPlacement{
        .image_id = image_id,
        .placement_id = placement_id,
        .row = row,
        .col = col,
        .cols = @intCast(control.cols),
        .rows = @intCast(control.rows),
        .z = control.z,
        .anchor_row = visible_top + @as(u64, row),
        .is_virtual = control.virtual != 0,
        .parent_image_id = parent_image_id,
        .parent_placement_id = parent_placement_id,
        .offset_x = control.parent_x,
        .offset_y = control.parent_y,
    };
    if (placement_id != 0) {
        if (findKittyPlacementIndex(self, image_id, placement_id)) |idx| {
            markKittyPlacementDirty(self, kitty.placements.items[idx], @src());
            kitty.placements.items[idx] = placement;
        } else {
            kitty.placements.append(self.allocator, placement) catch |err| {
                log.logf(.warning, "kitty placement append failed id={d} pid={d} err={s}", .{ image_id, placement_id, @errorName(err) });
                return "ENOMEM";
            };
        }
    } else {
        kitty.placements.append(self.allocator, placement) catch |err| {
            log.logf(.warning, "kitty placement append failed id={d} err={s}", .{ image_id, @errorName(err) });
            return "ENOMEM";
        };
    }
    markKittyPlacementDirty(self, placement, @src());
    log.logf(.info, "kitty placed id={d} row={d} col={d} cols={d} rows={d}", .{ image_id, row, col, placement.cols, placement.rows });

    if (control.cursor_movement != 1) {
        const cols = effectiveKittyColumns(self, control, image_id);
        const rows = effectiveKittyRows(self, control, image_id);
        if (rows > 0) {
            var moved: u32 = 0;
            while (moved < rows) : (moved += 1) {
                self.newline();
            }
            screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
        } else if (cols > 0) {
            screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
        }
        screen.wrap_next = false;
    }
    return null;
}

fn kittyValidateParentChain(self: anytype, parent: KittyPlacement, image_id: u32, placement_id: u32) ?[]const u8 {
    var current = parent;
    var depth: u8 = 1;
    while (true) {
        if (depth > kitty_parent_max_depth) return "ETOODEEP";
        if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
        if (current.parent_image_id == image_id and current.parent_placement_id == placement_id) return "ECYCLE";
        const next = findKittyPlacement(self, current.parent_image_id, current.parent_placement_id) orelse break;
        current = next;
        depth += 1;
    }
    return null;
}

fn kittyParentChainTooDeep(self: anytype, parent: KittyPlacement) bool {
    var current = parent;
    var depth: u8 = 1;
    while (true) {
        if (depth > kitty_parent_max_depth) return true;
        if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
        const next = findKittyPlacement(self, current.parent_image_id, current.parent_placement_id) orelse break;
        current = next;
        depth += 1;
    }
    return false;
}

fn findKittyPlacement(self: anytype, image_id: u32, placement_id: u32) ?KittyPlacement {
    const kitty = kittyStateConst(self);
    for (kitty.placements.items) |placement| {
        if (placement.image_id == image_id and placement.placement_id == placement_id) return placement;
    }
    return null;
}

fn findKittyPlacementIndex(self: anytype, image_id: u32, placement_id: u32) ?usize {
    const kitty = kittyStateConst(self);
    for (kitty.placements.items, 0..) |placement, idx| {
        if (placement.image_id == image_id and placement.placement_id == placement_id) return idx;
    }
    return null;
}

fn effectiveKittyColumns(self: anytype, control: KittyControl, image_id: u32) u32 {
    if (control.cols > 0) return control.cols;
    const cell_w = @as(u32, self.cell_width);
    const width_px = if (control.width > 0) control.width else blk: {
        const kitty = kittyStateConst(self);
        const image = findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
        break :blk image.width;
    };
    if (cell_w == 0 or width_px == 0) return 0;
    return std.math.divCeil(u32, width_px, cell_w) catch 0;
}

fn effectiveKittyRows(self: anytype, control: KittyControl, image_id: u32) u32 {
    if (control.rows > 0) return control.rows;
    const cell_h = @as(u32, self.cell_height);
    const height_px = if (control.height > 0) control.height else blk: {
        const kitty = kittyStateConst(self);
        const image = findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
        break :blk image.height;
    };
    if (cell_h == 0 or height_px == 0) return 0;
    if (height_px <= cell_h) return 0;
    return std.math.divCeil(u32, height_px, cell_h) catch 0;
}

fn deleteKittyImages(self: anytype, image_id: ?u32) void {
    const kitty = kittyState(self);
    if (image_id) |id| {
        var i: usize = 0;
        while (i < kitty.images.items.len) {
            if (kitty.images.items[i].id == id) {
                removeStoredKittyImageAt(self, i, true);
            } else {
                i += 1;
            }
        }
    } else {
        for (kitty.placements.items) |placement| {
            markKittyPlacementDirty(self, placement, @src());
        }
        clearKittyImages(self);
    }
}

fn deleteKittyPlacements(
    self: anytype,
    ctx: anytype,
    predicate: anytype,
) void {
    const kitty = kittyState(self);
    var idx: usize = 0;
    var changed = false;
    while (idx < kitty.placements.items.len) {
        if (predicate(ctx, self, kitty.placements.items[idx])) {
            markKittyPlacementDirty(self, kitty.placements.items[idx], @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

fn deleteKittyByAction(self: anytype, control: KittyControl) bool {
    const action = if (control.delete_action == 0) 'a' else control.delete_action;
    const id = resolveKittyImageId(control);
    const placement_id = control.placement_id orelse 0;
    const screen = self.activeScreenConst();
    const cursor_row = @as(u16, @intCast(screen.cursor.row));
    const cursor_col = @as(u16, @intCast(screen.cursor.col));
    const x = if (control.x > 0) control.x - 1 else 0;
    const y = if (control.y > 0) control.y - 1 else 0;
    const range_start = if (control.x > 0) control.x else 1;
    const range_end = if (control.y > 0) control.y else 0;
    const z = control.z;
    switch (action) {
        'a' => return deleteAllKittyPlacements(self),
        'A' => return deleteAllKittyImages(self),
        'i', 'I', 'n', 'N' => return deleteKittyByIdSelector(self, id, placement_id, action == 'I' or action == 'N'),
        'c', 'C' => return deleteKittyByPoint(self, cursor_row, cursor_col, action == 'C'),
        'p', 'P' => return deleteKittyByPoint(self, @as(u16, @intCast(y)), @as(u16, @intCast(x)), action == 'P'),
        'z', 'Z' => return deleteKittyByZ(self, z, action == 'Z'),
        'r', 'R' => return deleteKittyByRange(self, range_start, range_end, action == 'R'),
        'x', 'X' => return deleteKittyByColumn(self, @as(u16, @intCast(x)), action == 'X'),
        'y', 'Y' => return deleteKittyByRow(self, @as(u16, @intCast(y)), action == 'Y'),
        // AUDIT-07 policy lock: kitty delete selectors q/Q/f/F are explicitly deferred
        // in Zide and treated as invalid (`EINVAL`) instead of falling into unknown.
        'q', 'Q', 'f', 'F' => return false,
        else => return false,
    }
}

fn deleteAllKittyPlacements(self: anytype) bool {
    const Ctx = struct {
        fn pred(_: @This(), _: anytype, _: KittyPlacement) bool {
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{}, Ctx.pred);
    return true;
}

fn deleteAllKittyImages(self: anytype) bool {
    clearKittyImages(self);
    return true;
}

fn deleteKittyByIdSelector(self: anytype, id: ?u32, placement_id: u32, delete_images: bool) bool {
    if (id == null) return true;
    const target = id.?;
    if (delete_images) {
        deleteKittyImages(self, target);
        return true;
    }
    const Ctx = struct {
        target_id: u32,
        target_pid: u32,
        fn pred(ctx: @This(), _: anytype, placement: KittyPlacement) bool {
            if (placement.image_id != ctx.target_id) return false;
            if (ctx.target_pid != 0 and placement.placement_id != ctx.target_pid) return false;
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .target_id = target, .target_pid = placement_id }, Ctx.pred);
    return true;
}

fn deleteKittyByPoint(self: anytype, row: u16, col: u16, delete_images: bool) bool {
    const Ctx = struct {
        row: u16,
        col: u16,
        delete_images: bool,
        fn pred(ctx: @This(), session: anytype, placement: KittyPlacement) bool {
            if (!kittyPlacementIntersects(placement, ctx.row, ctx.col)) return false;
            if (ctx.delete_images) {
                deleteKittyImages(session, placement.image_id);
                return false;
            }
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .row = row, .col = col, .delete_images = delete_images }, Ctx.pred);
    return true;
}

fn deleteKittyByZ(self: anytype, z: i32, delete_images: bool) bool {
    const Ctx = struct {
        z: i32,
        delete_images: bool,
        fn pred(ctx: @This(), session: anytype, placement: KittyPlacement) bool {
            if (placement.z != ctx.z) return false;
            if (ctx.delete_images) {
                deleteKittyImages(session, placement.image_id);
                return false;
            }
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .z = z, .delete_images = delete_images }, Ctx.pred);
    return true;
}

fn deleteKittyByRange(self: anytype, range_start: u32, raw_range_end: u32, delete_images: bool) bool {
    const end = if (raw_range_end > 0) raw_range_end else range_start;
    if (range_start > end) return true;
    const Ctx = struct {
        start_id: u32,
        end_id: u32,
        delete_images: bool,
        fn pred(ctx: @This(), session: anytype, placement: KittyPlacement) bool {
            if (placement.image_id < ctx.start_id or placement.image_id > ctx.end_id) return false;
            if (ctx.delete_images) {
                deleteKittyImages(session, placement.image_id);
                return false;
            }
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .start_id = range_start, .end_id = end, .delete_images = delete_images }, Ctx.pred);
    return true;
}

fn deleteKittyByColumn(self: anytype, col: u16, delete_images: bool) bool {
    const Ctx = struct {
        col: u16,
        delete_images: bool,
        fn pred(ctx: @This(), session: anytype, placement: KittyPlacement) bool {
            if (!kittyPlacementIntersects(placement, placement.row, ctx.col)) return false;
            if (ctx.delete_images) {
                deleteKittyImages(session, placement.image_id);
                return false;
            }
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .col = col, .delete_images = delete_images }, Ctx.pred);
    return true;
}

fn deleteKittyByRow(self: anytype, row: u16, delete_images: bool) bool {
    const Ctx = struct {
        row: u16,
        delete_images: bool,
        fn pred(ctx: @This(), session: anytype, placement: KittyPlacement) bool {
            if (!kittyPlacementIntersects(placement, ctx.row, placement.col)) return false;
            if (ctx.delete_images) {
                deleteKittyImages(session, placement.image_id);
                return false;
            }
            return true;
        }
    };
    deleteKittyPlacements(self, Ctx{ .row = row, .delete_images = delete_images }, Ctx.pred);
    return true;
}

fn kittyPlacementIntersects(placement: KittyPlacement, row: u16, col: u16) bool {
    const width = if (placement.cols > 0) placement.cols else 1;
    const height = if (placement.rows > 0) placement.rows else 1;
    const end_row: u16 = placement.row + height - 1;
    const end_col: u16 = placement.col + width - 1;
    return row >= placement.row and row <= end_row and col >= placement.col and col <= end_col;
}

pub fn writeKittyResponse(self: anytype, control: KittyControl, image_id: u32, ok: bool, message: []const u8) void {
    const log = app_logger.logger("terminal.kitty");
    if (control.quiet == 2) return;
    if (control.quiet == 1 and ok) return;
    var seq = std.ArrayList(u8).empty;
    defer seq.deinit(self.allocator);
    _ = seq.appendSlice(self.allocator, "\x1b_G") catch |err| {
        log.logf(.warning, "kitty response prefix append failed err={s}", .{@errorName(err)});
        return;
    };
    var needs_comma = false;
    if (image_id != 0) {
        _ = seq.writer(self.allocator).print("i={d}", .{image_id}) catch |err| {
            log.logf(.warning, "kitty response image id append failed id={d} err={s}", .{ image_id, @errorName(err) });
            return;
        };
        needs_comma = true;
    }
    if (control.image_number) |num| {
        if (needs_comma) _ = seq.append(self.allocator, ',') catch |err| {
            log.logf(.warning, "kitty response comma append failed err={s}", .{@errorName(err)});
            return;
        };
        _ = seq.writer(self.allocator).print("I={d}", .{num}) catch |err| {
            log.logf(.warning, "kitty response image number append failed num={d} err={s}", .{ num, @errorName(err) });
            return;
        };
        needs_comma = true;
    }
    if (control.placement_id) |pid| {
        if (needs_comma) _ = seq.append(self.allocator, ',') catch |err| {
            log.logf(.warning, "kitty response comma append failed err={s}", .{@errorName(err)});
            return;
        };
        _ = seq.writer(self.allocator).print("p={d}", .{pid}) catch |err| {
            log.logf(.warning, "kitty response placement id append failed pid={d} err={s}", .{ pid, @errorName(err) });
            return;
        };
    }
    _ = seq.append(self.allocator, ';') catch |err| {
        log.logf(.warning, "kitty response separator append failed err={s}", .{@errorName(err)});
        return;
    };
    _ = seq.appendSlice(self.allocator, message) catch |err| {
        log.logf(.warning, "kitty response message append failed len={d} err={s}", .{ message.len, @errorName(err) });
        return;
    };
    _ = seq.appendSlice(self.allocator, "\x1b\\") catch |err| {
        log.logf(.warning, "kitty response terminator append failed err={s}", .{@errorName(err)});
        return;
    };
    self.writePtyBytes(seq.items) catch |err| {
        app_logger.logger("terminal.kitty").logf(.warning, "kitty response write failed len={d} err={s}", .{ seq.items.len, @errorName(err) });
    };
}

pub fn clearKittyImages(self: anytype) void {
    const kitty = kittyState(self);
    clearKittyImagesState(self, kitty);
}

pub fn clearAllKittyImages(self: anytype) void {
    clearKittyImagesState(self, &self.kitty_primary);
    clearKittyImagesState(self, &self.kitty_alt);
}

fn clearKittyImagesState(self: anytype, kitty: *KittyState) void {
    for (kitty.images.items) |image| {
        self.allocator.free(image.data);
    }
    kitty.images.clearRetainingCapacity();
    kitty.placements.clearRetainingCapacity();
    var partial_it = kitty.partials.iterator();
    while (partial_it.next()) |entry| {
        entry.value_ptr.data.deinit(self.allocator);
    }
    kitty.partials.clearRetainingCapacity();
    kitty.total_bytes = 0;
    kitty.generation += 1;
}

test "kitty dirty region derives implicit cell span from image dimensions" {
    const image = KittyImage{
        .id = 1,
        .width = 20,
        .height = 40,
        .format = .rgba,
        .data = &.{},
        .version = 1,
    };
    const placement = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 2,
        .col = 3,
        .cols = 0,
        .rows = 0,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };

    switch (kittyPlacementDirtyRegion(image, placement, 10, 10, 8, 16)) {
        .partial => |region| {
            try std.testing.expectEqual(@as(usize, 2), region.start_row);
            try std.testing.expectEqual(@as(usize, 4), region.end_row);
            try std.testing.expectEqual(@as(usize, 3), region.start_col);
            try std.testing.expectEqual(@as(usize, 5), region.end_col);
        },
        else => try std.testing.expect(false),
    }
}

test "kitty dirty region falls back to full when implicit span cannot be derived" {
    const image = KittyImage{
        .id = 1,
        .width = 20,
        .height = 40,
        .format = .rgba,
        .data = &.{},
        .version = 1,
    };
    const placement = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 0,
        .rows = 0,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };

    try std.testing.expectEqual(
        KittyDirtyPlacement.full,
        kittyPlacementDirtyRegion(image, placement, 10, 10, 0, 16),
    );
}
