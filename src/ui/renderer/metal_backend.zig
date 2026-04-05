const std = @import("std");
const builtin = @import("builtin");
const macos_metal_host = @import("../../platform/macos_metal_host.zig");
const terminal_font = @import("../terminal_font.zig");
const types = @import("types.zig");

const objc = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

const CGSize = extern struct {
    width: f64,
    height: f64,
};

const MTLClearColor = extern struct {
    red: f64,
    green: f64,
    blue: f64,
    alpha: f64,
};

const MTLRegion = extern struct {
    origin: MTLOrigin,
    size: MTLSize,
};

const MTLOrigin = extern struct {
    x: usize,
    y: usize,
    z: usize,
};

const MTLSize = extern struct {
    width: usize,
    height: usize,
    depth: usize,
};

const pixel_format_bgra8_unorm: usize = 80;
const pixel_format_r8_unorm: usize = 10;
const load_action_clear: usize = 2;
const store_action_store: usize = 1;
const texture_usage_shader_read: usize = 1;
const default_glyph_atlas_width: i32 = 2048;
const default_glyph_atlas_height: i32 = 2048;

pub const AtlasTexture = struct {
    texture: *anyopaque,
    width: i32,
    height: i32,
    pixel_format: usize,
};

pub const GlyphAtlas = struct {
    coverage: AtlasTexture,
    color: AtlasTexture,
    diagnostic_seeded: bool,
};

pub const AtlasPreview = struct {
    source_rect: types.Rect,
    dest_x: i32,
    dest_y: i32,
};

pub const BackendContext = struct {
    host: macos_metal_host.Host,
    metal_layer: *anyopaque,
    device: *anyopaque,
    command_queue: *anyopaque,
    glyph_atlas: GlyphAtlas,
    drawable_width: i32,
    drawable_height: i32,
};

pub const Frame = struct {
    drawable: *anyopaque,
    command_buffer: *anyopaque,
};

pub const Readback = struct {
    buffer: *anyopaque,
    width: i32,
    height: i32,
    bytes_per_row: usize,
};

extern "Metal" fn MTLCreateSystemDefaultDevice() ?*anyopaque;

fn classPointer(class_name: [*:0]const u8) ?*anyopaque {
    return objc.objc_getClass(class_name);
}

fn msgSendSetPointer(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendClassPointer(target: *anyopaque, selector_name: [*:0]const u8) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel);
}

fn msgSendClassU64U64U64BoolPointer(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    value0: usize,
    value1: usize,
    value2: usize,
    value3: bool,
) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize, usize, usize, bool) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value0, value1, value2, value3);
}

fn msgSendPointer(target: *anyopaque, selector_name: [*:0]const u8) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel);
}

fn msgSendSetU64(target: *anyopaque, selector_name: [*:0]const u8, value: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendSetBool(target: *anyopaque, selector_name: [*:0]const u8, value: bool) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, bool) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendSetSize(target: *anyopaque, selector_name: [*:0]const u8, value: CGSize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, CGSize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendVoid(target: *anyopaque, selector_name: [*:0]const u8) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel);
}

fn msgSendPointerArgVoid(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendPointerArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value);
}

fn msgSendRegionU64BytesU64Void(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    region: MTLRegion,
    mipmap_level: usize,
    bytes: [*]const u8,
    bytes_per_row: usize,
) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (
        *anyopaque,
        objc.SEL,
        MTLRegion,
        usize,
        [*]const u8,
        usize,
    ) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, region, mipmap_level, bytes, bytes_per_row);
}

fn msgSendU64ArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value: usize) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value);
}

fn msgSendSetClearColor(target: *anyopaque, selector_name: [*:0]const u8, value: MTLClearColor) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, MTLClearColor) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value);
}

fn msgSendU64U64ArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value0: usize, value1: usize) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize, usize) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value0, value1);
}

fn msgSendCopyTextureToBuffer(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    texture: *anyopaque,
    source_slice: usize,
    source_level: usize,
    source_origin: MTLOrigin,
    source_size: MTLSize,
    buffer: *anyopaque,
    destination_offset: usize,
    destination_bytes_per_row: usize,
    destination_bytes_per_image: usize,
) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (
        *anyopaque,
        objc.SEL,
        *anyopaque,
        usize,
        usize,
        MTLOrigin,
        MTLSize,
        *anyopaque,
        usize,
        usize,
        usize,
    ) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(
        target,
        sel,
        texture,
        source_slice,
        source_level,
        source_origin,
        source_size,
        buffer,
        destination_offset,
        destination_bytes_per_row,
        destination_bytes_per_image,
    );
}

fn msgSendCopyTextureToTexture(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    source_texture: *anyopaque,
    source_slice: usize,
    source_level: usize,
    source_origin: MTLOrigin,
    source_size: MTLSize,
    destination_texture: *anyopaque,
    destination_slice: usize,
    destination_level: usize,
    destination_origin: MTLOrigin,
) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (
        *anyopaque,
        objc.SEL,
        *anyopaque,
        usize,
        usize,
        MTLOrigin,
        MTLSize,
        *anyopaque,
        usize,
        usize,
        MTLOrigin,
    ) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(
        target,
        sel,
        source_texture,
        source_slice,
        source_level,
        source_origin,
        source_size,
        destination_texture,
        destination_slice,
        destination_level,
        destination_origin,
    );
}

fn retainObject(object: *anyopaque) *anyopaque {
    return msgSendPointer(object, "retain").?;
}

fn releaseObject(object: *anyopaque) void {
    msgSendVoid(object, "release");
}

fn createAtlasTexture(
    device: *anyopaque,
    width: i32,
    height: i32,
    pixel_format: usize,
) ?AtlasTexture {
    if (builtin.target.os.tag != .macos) return null;
    const descriptor_class = classPointer("MTLTextureDescriptor") orelse return null;
    const descriptor = msgSendClassU64U64U64BoolPointer(
        descriptor_class,
        "texture2DDescriptorWithPixelFormat:width:height:mipmapped:",
        pixel_format,
        @intCast(width),
        @intCast(height),
        false,
    ) orelse return null;
    msgSendSetU64(descriptor, "setUsage:", texture_usage_shader_read);
    const texture = msgSendPointerArgPointer(device, "newTextureWithDescriptor:", descriptor) orelse return null;
    return .{
        .texture = texture,
        .width = width,
        .height = height,
        .pixel_format = pixel_format,
    };
}

pub fn createGlyphAtlas(
    device: *anyopaque,
    width: i32,
    height: i32,
) ?GlyphAtlas {
    if (builtin.target.os.tag != .macos) return null;
    const coverage = createAtlasTexture(device, width, height, pixel_format_r8_unorm) orelse return null;
    errdefer releaseObject(coverage.texture);
    const color = createAtlasTexture(device, width, height, pixel_format_bgra8_unorm) orelse return null;
    var atlas = GlyphAtlas{
        .coverage = coverage,
        .color = color,
        .diagnostic_seeded = false,
    };
    atlas.diagnostic_seeded = seedGlyphAtlasDiagnostics(&atlas);
    return atlas;
}

pub fn deinitGlyphAtlas(atlas: *GlyphAtlas) void {
    if (builtin.target.os.tag != .macos) return;
    releaseObject(atlas.coverage.texture);
    releaseObject(atlas.color.texture);
}

fn uploadAtlasTexture(texture: *const AtlasTexture, rect: types.Rect, bytes_per_pixel: usize, data: []const u8) bool {
    if (builtin.target.os.tag != .macos) return false;
    const origin_x: i32 = @intFromFloat(rect.x);
    const origin_y: i32 = @intFromFloat(rect.y);
    const width: i32 = @intFromFloat(rect.width);
    const height: i32 = @intFromFloat(rect.height);
    if (width <= 0 or height <= 0) return false;
    const required_len: usize = @intCast(width * height * @as(i32, @intCast(bytes_per_pixel)));
    if (data.len < required_len) return false;
    msgSendRegionU64BytesU64Void(
        texture.texture,
        "replaceRegion:mipmapLevel:withBytes:bytesPerRow:",
        .{
            .origin = .{
                .x = @intCast(origin_x),
                .y = @intCast(origin_y),
                .z = 0,
            },
            .size = .{
                .width = @intCast(width),
                .height = @intCast(height),
                .depth = 1,
            },
        },
        0,
        data.ptr,
        @intCast(width * @as(i32, @intCast(bytes_per_pixel))),
    );
    return true;
}

pub fn uploadGlyphCoverage(
    atlas: *GlyphAtlas,
    rect: types.Rect,
    data: []const u8,
) bool {
    return uploadAtlasTexture(&atlas.coverage, rect, 1, data);
}

pub fn uploadGlyphColor(
    atlas: *GlyphAtlas,
    rect: types.Rect,
    data: []const u8,
) bool {
    const converted = std.heap.page_allocator.alloc(u8, data.len) catch return false;
    defer std.heap.page_allocator.free(converted);
    var idx: usize = 0;
    while (idx + 3 < data.len) : (idx += 4) {
        converted[idx + 0] = data[idx + 2];
        converted[idx + 1] = data[idx + 1];
        converted[idx + 2] = data[idx + 0];
        converted[idx + 3] = data[idx + 3];
    }
    return uploadAtlasTexture(&atlas.color, rect, 4, converted);
}

pub fn glyphAtlasReady(context: *const BackendContext) bool {
    return context.glyph_atlas.diagnostic_seeded;
}

fn uploadCoverageOpaque(ctx: ?*anyopaque, rect: types.Rect, data: []const u8) bool {
    const raw = ctx orelse return false;
    const context: *BackendContext = @ptrCast(@alignCast(raw));
    return uploadGlyphCoverage(&context.glyph_atlas, rect, data);
}

fn uploadColorOpaque(ctx: ?*anyopaque, rect: types.Rect, data: []const u8) bool {
    const raw = ctx orelse return false;
    const context: *BackendContext = @ptrCast(@alignCast(raw));
    return uploadGlyphColor(&context.glyph_atlas, rect, data);
}

pub fn terminalFontAtlasUploadHooks(context: *BackendContext) terminal_font.AtlasUploadHooks {
    return .{
        .ctx = context,
        .upload_coverage = uploadCoverageOpaque,
        .upload_color = uploadColorOpaque,
    };
}

pub fn blitAtlasColorPreview(
    context: *BackendContext,
    frame: *Frame,
    source_rect: types.Rect,
    dest_x: i32,
    dest_y: i32,
) bool {
    if (builtin.target.os.tag != .macos) return false;
    const drawable_texture = msgSendPointer(frame.drawable, "texture") orelse return false;
    const blit_encoder = msgSendPointer(frame.command_buffer, "blitCommandEncoder") orelse return false;
    const width: i32 = @intFromFloat(source_rect.width);
    const height: i32 = @intFromFloat(source_rect.height);
    if (width <= 0 or height <= 0) {
        msgSendVoid(blit_encoder, "endEncoding");
        return false;
    }
    msgSendCopyTextureToTexture(
        blit_encoder,
        "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
        context.glyph_atlas.color.texture,
        0,
        0,
        .{
            .x = @intCast(@as(i32, @intFromFloat(source_rect.x))),
            .y = @intCast(@as(i32, @intFromFloat(source_rect.y))),
            .z = 0,
        },
        .{
            .width = @intCast(width),
            .height = @intCast(height),
            .depth = 1,
        },
        drawable_texture,
        0,
        0,
        .{
            .x = @intCast(@max(0, dest_x)),
            .y = @intCast(@max(0, dest_y)),
            .z = 0,
        },
    );
    msgSendVoid(blit_encoder, "endEncoding");
    return true;
}

pub fn drawAtlasPreview(
    context: *BackendContext,
    frame: *Frame,
    preview: AtlasPreview,
) bool {
    return blitAtlasColorPreview(
        context,
        frame,
        preview.source_rect,
        preview.dest_x,
        preview.dest_y,
    );
}

fn seedGlyphAtlasDiagnostics(atlas: *GlyphAtlas) bool {
    const coverage = [_]u8{
        0x00, 0x55, 0xAA, 0xFF,
        0xFF, 0xAA, 0x55, 0x00,
        0x00, 0x55, 0xAA, 0xFF,
        0xFF, 0xAA, 0x55, 0x00,
    };
    const color = [_]u8{
        0xFF, 0x40, 0x40, 0xFF, 0x40, 0xFF, 0x40, 0xFF, 0x40, 0x40, 0xFF, 0xFF, 0xFF, 0xFF, 0x40, 0xFF,
        0x40, 0xFF, 0x40, 0xFF, 0x40, 0x40, 0xFF, 0xFF, 0xFF, 0xFF, 0x40, 0xFF, 0xFF, 0x40, 0x40, 0xFF,
        0x40, 0x40, 0xFF, 0xFF, 0xFF, 0xFF, 0x40, 0xFF, 0xFF, 0x40, 0x40, 0xFF, 0x40, 0xFF, 0x40, 0xFF,
        0xFF, 0xFF, 0x40, 0xFF, 0xFF, 0x40, 0x40, 0xFF, 0x40, 0xFF, 0x40, 0xFF, 0x40, 0x40, 0xFF, 0xFF,
    };
    const rect = types.Rect{
        .x = 0,
        .y = 0,
        .width = 4,
        .height = 4,
    };
    return uploadGlyphCoverage(atlas, rect, coverage[0..]) and
        uploadGlyphColor(atlas, rect, color[0..]);
}

pub fn createBackendContext(
    host: macos_metal_host.Host,
    drawable_width: i32,
    drawable_height: i32,
) ?BackendContext {
    if (builtin.target.os.tag != .macos) return null;
    const device = MTLCreateSystemDefaultDevice() orelse return null;
    const command_queue = msgSendPointer(device, "newCommandQueue") orelse {
        releaseObject(device);
        return null;
    };
    const glyph_atlas = createGlyphAtlas(device, default_glyph_atlas_width, default_glyph_atlas_height) orelse {
        releaseObject(command_queue);
        releaseObject(device);
        return null;
    };
    msgSendSetPointer(host.layer(), "setDevice:", device);
    msgSendSetU64(host.layer(), "setPixelFormat:", pixel_format_bgra8_unorm);
    msgSendSetBool(host.layer(), "setFramebufferOnly:", true);
    msgSendSetSize(host.layer(), "setDrawableSize:", .{
        .width = @as(f64, @floatFromInt(drawable_width)),
        .height = @as(f64, @floatFromInt(drawable_height)),
    });
    return .{
        .host = host,
        .metal_layer = host.layer(),
        .device = device,
        .command_queue = command_queue,
        .glyph_atlas = glyph_atlas,
        .drawable_width = drawable_width,
        .drawable_height = drawable_height,
    };
}

pub fn resizeBackendContext(
    context: *BackendContext,
    drawable_width: i32,
    drawable_height: i32,
) void {
    context.drawable_width = drawable_width;
    context.drawable_height = drawable_height;
    if (builtin.target.os.tag != .macos) return;
    msgSendSetSize(context.metal_layer, "setDrawableSize:", .{
        .width = @as(f64, @floatFromInt(drawable_width)),
        .height = @as(f64, @floatFromInt(drawable_height)),
    });
}

pub fn deinitBackendContext(context: *BackendContext) void {
    if (builtin.target.os.tag != .macos) return;
    deinitGlyphAtlas(&context.glyph_atlas);
    releaseObject(context.command_queue);
    msgSendVoid(context.device, "release");
}

pub fn acquireFrame(context: *BackendContext) ?Frame {
    if (builtin.target.os.tag != .macos) return null;
    const drawable_unretained = msgSendPointer(context.metal_layer, "nextDrawable") orelse return null;
    const drawable = retainObject(drawable_unretained);
    errdefer releaseObject(drawable);

    const command_buffer_unretained = msgSendPointer(context.command_queue, "commandBuffer") orelse return null;
    const command_buffer = retainObject(command_buffer_unretained);

    return .{
        .drawable = drawable,
        .command_buffer = command_buffer,
    };
}

pub fn clearFrame(frame: *Frame, rgba: [4]f32) bool {
    if (builtin.target.os.tag != .macos) return false;
    const render_pass_descriptor_class = classPointer("MTLRenderPassDescriptor") orelse return false;
    const render_pass_descriptor = msgSendClassPointer(render_pass_descriptor_class, "renderPassDescriptor") orelse return false;
    const color_attachments = msgSendPointer(render_pass_descriptor, "colorAttachments") orelse return false;
    const color_attachment = msgSendU64ArgPointer(color_attachments, "objectAtIndexedSubscript:", 0) orelse return false;
    const drawable_texture = msgSendPointer(frame.drawable, "texture") orelse return false;
    msgSendSetPointer(color_attachment, "setTexture:", drawable_texture);
    msgSendSetU64(color_attachment, "setLoadAction:", load_action_clear);
    msgSendSetU64(color_attachment, "setStoreAction:", store_action_store);
    msgSendSetClearColor(color_attachment, "setClearColor:", .{
        .red = @as(f64, rgba[0]),
        .green = @as(f64, rgba[1]),
        .blue = @as(f64, rgba[2]),
        .alpha = @as(f64, rgba[3]),
    });
    const encoder = msgSendPointerArgPointer(frame.command_buffer, "renderCommandEncoderWithDescriptor:", render_pass_descriptor) orelse return false;
    msgSendVoid(encoder, "endEncoding");
    return true;
}

pub fn prepareFrameReadback(context: *BackendContext, frame: *Frame) ?Readback {
    if (builtin.target.os.tag != .macos) return null;
    if (context.drawable_width <= 0 or context.drawable_height <= 0) return null;

    const texture = msgSendPointer(frame.drawable, "texture") orelse return null;
    const width: usize = @intCast(context.drawable_width);
    const height: usize = @intCast(context.drawable_height);
    const packed_bytes_per_row = width * 4;
    const bytes_per_row = std.mem.alignForward(usize, packed_bytes_per_row, 256);
    const bytes_per_image = bytes_per_row * height;
    const buffer = msgSendU64U64ArgPointer(context.device, "newBufferWithLength:options:", bytes_per_image, 0) orelse return null;
    errdefer releaseObject(buffer);

    const blit_encoder = msgSendPointer(frame.command_buffer, "blitCommandEncoder") orelse return null;
    msgSendCopyTextureToBuffer(
        blit_encoder,
        "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toBuffer:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:",
        texture,
        0,
        0,
        .{ .x = 0, .y = 0, .z = 0 },
        .{ .width = width, .height = height, .depth = 1 },
        buffer,
        0,
        bytes_per_row,
        bytes_per_image,
    );
    msgSendVoid(blit_encoder, "endEncoding");

    return .{
        .buffer = buffer,
        .width = context.drawable_width,
        .height = context.drawable_height,
        .bytes_per_row = bytes_per_row,
    };
}

pub fn copyReadbackRgba(allocator: std.mem.Allocator, readback: *const Readback) ![]u8 {
    if (builtin.target.os.tag != .macos) return error.UnsupportedPlatform;
    if (readback.width <= 0 or readback.height <= 0) return error.InvalidDimensions;

    const width: usize = @intCast(readback.width);
    const height: usize = @intCast(readback.height);
    const packed_bytes_per_row = width * 4;
    const total_bytes = packed_bytes_per_row * height;
    const source = msgSendPointer(readback.buffer, "contents") orelse return error.MetalReadbackUnavailable;
    const source_bytes: [*]const u8 = @ptrCast(source);

    const rgba = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(rgba);

    var row: usize = 0;
    while (row < height) : (row += 1) {
        const src_offset = row * readback.bytes_per_row;
        const dst_offset = row * packed_bytes_per_row;
        @memcpy(rgba[dst_offset .. dst_offset + packed_bytes_per_row], source_bytes[src_offset .. src_offset + packed_bytes_per_row]);
    }
    return rgba;
}

pub fn deinitReadback(readback: *Readback) void {
    if (builtin.target.os.tag != .macos) return;
    releaseObject(readback.buffer);
}

pub fn abandonFrame(frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    releaseObject(frame.command_buffer);
    releaseObject(frame.drawable);
}

pub fn encodePresent(frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    msgSendPointerArgVoid(frame.command_buffer, "presentDrawable:", frame.drawable);
}

pub fn commitFrame(frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    msgSendVoid(frame.command_buffer, "commit");
}

pub fn waitForFrame(frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    msgSendVoid(frame.command_buffer, "waitUntilCompleted");
}

pub fn releaseFrame(frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    releaseObject(frame.command_buffer);
    releaseObject(frame.drawable);
}

pub fn presentFrame(_: *BackendContext, frame: *Frame) void {
    if (builtin.target.os.tag != .macos) return;
    encodePresent(frame);
    commitFrame(frame);
    releaseFrame(frame);
}
