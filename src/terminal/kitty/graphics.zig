const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");
const transport_mod = @import("transport.zig");
const placement_mod = @import("placement_ops.zig");
const storage_mod = @import("storage_ops.zig");

pub const KittyImageFormat = common.KittyImageFormat;
pub const KittyImage = common.KittyImage;
pub const KittyPlacement = common.KittyPlacement;
pub const KittyKV = common.KittyKV;
pub const KittyPartial = common.KittyPartial;
pub const KittyControl = common.KittyControl;
pub const KittyBuildError = common.KittyBuildError;
pub const KittyState = common.KittyState;

const KittyTransport = transport_mod.KittyTransport;
const KittyPlacementOps = placement_mod.KittyPlacementOps;
const KittyStorageOps = storage_mod.KittyStorageOps;

const KittyProtocolOps = struct {
    pub fn parseAndDispatch(self: anytype, payload: []const u8) void {
        const log = app_logger.logger("terminal.kitty");
        var control = KittyControl{};
        var raw_kv = std.ArrayList(KittyKV).empty;
        defer raw_kv.deinit(self.allocator);
        const data = parseControl(self.allocator, payload, &control, &raw_kv);
        if (!validateControl(control)) {
            log.logf(.info, "kitty invalid command a={c} data_len={d}", .{ control.action, data.len });
            writeResponse(self, control, resolveImageId(control) orelse 0, false, "EINVAL");
            return;
        }
        switch (control.action) {
            'd' => handleDelete(self, control),
            'p' => handlePlacementRequest(self, control),
            'q' => handleQuery(self, control, data),
            't', 'T' => handleUpload(self, control, data),
            else => {},
        }
    }

    fn handleDelete(self: anytype, control: KittyControl) void {
        if (!deleteKittyByAction(self, control)) {
            writeResponse(self, control, resolveImageId(control) orelse 0, false, "EINVAL");
        }
    }

    fn handlePlacementRequest(self: anytype, control: KittyControl) void {
        const image_id = resolveImageId(control) orelse return;
        if (placeKittyImage(self, image_id, control)) |err_msg| {
            writeResponse(self, control, image_id, false, err_msg);
            return;
        }
        writeResponse(self, control, image_id, true, "OK");
    }

    fn handleQuery(self: anytype, control: KittyControl, data: []const u8) void {
        if (handleQueryEarlyReply(self, control, data.len)) return;

        const image_id = resolveImageId(control).?;
        var query_control = control;
        if (query_control.format == 0) {
            query_control.format = 32;
        }
        if (handleQueryPayloadPreflightReply(self, query_control, image_id)) return;

        var chunk = KittyTransport.loadPayload(self, &query_control, data) orelse {
            handleQueryPayloadLoadFailureReply(self, query_control, image_id);
            return;
        };
        chunk = inflateQueryChunk(self, query_control, image_id, chunk) orelse return;
        defer self.allocator.free(chunk);

        if (handleQueryPayloadSizeReply(self, query_control, image_id, chunk.len)) return;
        _ = handleQueryChunkBuildReply(self, query_control, image_id, chunk.len, QueryBuilder{ .chunk = chunk }, QueryBuilder.run);
    }

    fn handleUpload(self: anytype, control: KittyControl, data: []const u8) void {
        const log = app_logger.logger("terminal.kitty");
        const upload = resolveUpload(self, control) orelse return;
        var upload_control = upload.control;

        const decoded = KittyTransport.loadPayload(self, &upload_control, data) orelse {
            log.logf(.info, "kitty decode failed len={d}", .{data.len});
            common.clearKittyLoading(common.kittyState(self), upload.image_id);
            writeResponse(self, upload_control, upload.image_id, false, "EINVAL");
            return;
        };

        const final_data = KittyTransport.accumulate(self, upload.image_id, &upload_control, decoded) orelse {
            if (!upload_control.more) {
                common.clearKittyLoading(common.kittyState(self), upload.image_id);
            }
            return;
        };

        finishUpload(self, upload_control, upload.image_id, final_data);
    }

    fn finishUpload(self: anytype, control: KittyControl, image_id: u32, final_data: []u8) void {
        const log = app_logger.logger("terminal.kitty");
        var upload_control = control;
        defer common.clearKittyLoading(common.kittyState(self), image_id);

        if (upload_control.format == 0) {
            upload_control.format = 32;
        }
        if (handleUploadSizeReply(self, upload_control, image_id, final_data)) return;

        const image = KittyTransport.buildImage(self, image_id, upload_control, final_data) catch |err| {
            log.logf(.info, "kitty build failed id={d} format={d} data_len={d}", .{ image_id, upload_control.format, final_data.len });
            writeResponse(self, upload_control, image_id, false, queryBuildErrorReplyMessage(err));
            return;
        };
        KittyStorageOps.store(self, image);
        if (upload_control.action == 'T') {
            if (placeKittyImage(self, image_id, upload_control)) |err_msg| {
                writeResponse(self, upload_control, image_id, false, err_msg);
                return;
            }
        }
        writeResponse(self, upload_control, image_id, true, "OK");
    }

    fn handleUploadSizeReply(self: anytype, control: KittyControl, image_id: u32, final_data: []u8) bool {
        if (KittyTransport.expectedDataBytes(control)) |expected| {
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
                writeResponse(self, control, image_id, false, message.items);
                return true;
            }
        }
        return false;
    }

    fn handleQueryEarlyReply(self: anytype, control: KittyControl, data_len: usize) bool {
        const image_id = resolveImageId(control) orelse return true;
        if (data_len == 0 and control.size == 0 and control.width == 0 and control.height == 0) {
            writeResponse(self, control, image_id, true, "OK");
            return true;
        }
        return false;
    }

    fn handleQueryPayloadPreflightReply(self: anytype, control: KittyControl, image_id: u32) bool {
        if (control.more or control.offset != 0) {
            writeResponse(self, control, image_id, false, "EINVAL");
            return true;
        }
        return false;
    }

    fn handleQueryPayloadLoadFailureReply(self: anytype, control: KittyControl, image_id: u32) void {
        writeResponse(self, control, image_id, false, "EINVAL");
    }

    fn handleQueryPayloadSizeReply(self: anytype, control: KittyControl, image_id: u32, chunk_len: usize) bool {
        const log = app_logger.logger("terminal.kitty");
        if (KittyTransport.expectedDataBytes(control)) |expected| {
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
                writeResponse(self, control, image_id, false, message.items);
                return true;
            }
        }
        return false;
    }

    fn handleQueryChunkBuildReply(
        self: anytype,
        control: KittyControl,
        image_id: u32,
        chunk_len: usize,
        builder_ctx: anytype,
        comptime build_fn: anytype,
    ) bool {
        if (handleQueryPayloadSizeReply(self, control, image_id, chunk_len)) {
            return true;
        }
        build_fn(builder_ctx, self, image_id, control) catch |err| {
            writeResponse(self, control, image_id, false, queryBuildErrorReplyMessage(err));
            return true;
        };
        writeResponse(self, control, image_id, true, "OK");
        return true;
    }

    fn queryBuildErrorReplyMessage(err: KittyBuildError) []const u8 {
        return switch (err) {
            error.BadPng => "EBADPNG",
            else => "EINVAL",
        };
    }

    fn inflateQueryChunk(self: anytype, control: KittyControl, image_id: u32, chunk: []u8) ?[]u8 {
        if (control.compression == 'z') {
            const inflated = KittyTransport.inflate(self, chunk, control.size) orelse {
                self.allocator.free(chunk);
                writeResponse(self, control, image_id, false, "EINVAL");
                return null;
            };
            self.allocator.free(chunk);
            return inflated;
        }
        if (control.compression != 0) {
            self.allocator.free(chunk);
            writeResponse(self, control, image_id, false, "EINVAL");
            return null;
        }
        return chunk;
    }

    fn resolveUpload(self: anytype, control: KittyControl) ?UploadResolution {
        const kitty = common.kittyState(self);
        var upload_control = control;
        var image_id = resolveImageId(upload_control);
        if (kitty.loading_image_id) |loading_id| {
            if (image_id) |explicit_id| {
                if (explicit_id != loading_id and upload_control.more) {
                    kitty.loading_image_id = null;
                    writeResponse(self, upload_control, explicit_id, false, "EINVAL");
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

    fn parseControl(
        allocator: std.mem.Allocator,
        payload: []const u8,
        control: *KittyControl,
        raw_kv: *std.ArrayList(KittyKV),
    ) []const u8 {
        return parseKittyControl(allocator, payload, control, raw_kv);
    }

    fn validateControl(control: KittyControl) bool {
        return validateKittyControl(control);
    }

    fn resolveImageId(control: KittyControl) ?u32 {
        return resolveKittyImageId(control);
    }

    fn writeResponse(self: anytype, control: KittyControl, image_id: u32, ok: bool, message: []const u8) void {
        writeKittyResponse(self, control, image_id, ok, message);
    }
};

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

pub fn kittyState(self: anytype) *KittyState {
    return common.kittyState(self);
}

pub fn kittyStateConst(self: anytype) *const KittyState {
    return common.kittyStateConst(self);
}

pub fn parseKittyGraphics(self: anytype, payload: []const u8) void {
    KittyProtocolOps.parseAndDispatch(self, payload);
}

const QueryBuilder = struct {
    chunk: []u8,

    fn run(ctx: @This(), session: anytype, target_image_id: u32, ctl: KittyControl) KittyBuildError!void {
        const image = try KittyTransport.buildImage(session, target_image_id, ctl, ctx.chunk);
        session.allocator.free(image.data);
    }
};

const UploadResolution = struct {
    image_id: u32,
    control: KittyControl,
};

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
        if (control.format != 0 and KittyTransport.formatFor(control.format) == null) return false;
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

pub fn updateKittyPlacementsForScroll(self: anytype) void {
    placement_mod.updateKittyPlacementsForScroll(self);
}

pub fn shiftKittyPlacementsUp(self: anytype, top: usize, bottom: usize, count: usize) void {
    placement_mod.shiftKittyPlacementsUp(self, top, bottom, count);
}

pub fn shiftKittyPlacementsDown(self: anytype, top: usize, bottom: usize, count: usize) void {
    placement_mod.shiftKittyPlacementsDown(self, top, bottom, count);
}

fn placeKittyImage(self: anytype, image_id: u32, control: KittyControl) ?[]const u8 {
    return placement_mod.placeKittyImage(self, image_id, control);
}

fn deleteKittyImages(self: anytype, image_id: ?u32) void {
    KittyStorageOps.deleteImages(self, image_id);
}

fn deleteKittyPlacements(
    self: anytype,
    ctx: anytype,
    predicate: anytype,
) void {
    const kitty = common.kittyState(self);
    var idx: usize = 0;
    var changed = false;
    while (idx < kitty.placements.items.len) {
        if (predicate(ctx, self, kitty.placements.items[idx])) {
            KittyPlacementOps.markPlacementDirty(self, kitty.placements.items[idx], @src());
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
    KittyStorageOps.clearActive(self);
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
    KittyStorageOps.clearActive(self);
}

pub fn clearAllKittyImages(self: anytype) void {
    KittyStorageOps.clearAll(self);
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

    switch (common.kittyPlacementDirtyRegion(image, placement, 10, 10, 8, 16)) {
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
        common.KittyDirtyPlacement.full,
        common.kittyPlacementDirtyRegion(image, placement, 10, 10, 0, 16),
    );
}
