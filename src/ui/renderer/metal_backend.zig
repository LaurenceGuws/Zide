const std = @import("std");
const builtin = @import("builtin");
const iface = @import("interface.zig");
const macos_metal_host = @import("../../platform/macos_metal_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const capability_contract = @import("capability_contract.zig");
const bootstrap_contract = @import("bootstrap_contract.zig");
const metal_runtime_state = @import("metal_runtime_state.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const presentable_contract = @import("presentable_contract.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_frame_host = @import("renderer_frame_host.zig");
const screenshot = @import("screenshot.zig");
const surface_draw = @import("surface_draw.zig");
const window_init = @import("window_init.zig");
const terminal_font = @import("../terminal_font.zig");
const types = @import("types.zig");
const app_logger = @import("../../app_logger.zig");

const objc = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {
    pub const SEL = *anyopaque;

    pub fn objc_getClass(name: [*:0]const u8) ?*anyopaque {
        _ = name;
        return null;
    }

    pub fn sel_registerName(name: [*:0]const u8) SEL {
        _ = name;
        return @ptrFromInt(1);
    }

    pub fn objc_msgSend() callconv(.c) void {
        unreachable;
    }
};

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

const AtlasVertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const AtlasFragmentUniforms = extern struct {
    tint: [4]f32,
    alpha_only: u32,
    _padding: [3]u32 = .{ 0, 0, 0 },
};

pub const PixelClipRect = surface_draw.PixelClipRect;
pub const AtlasPreviewSource = metal_runtime_state.AtlasPreviewSource;
const PresentableSurface = presentable_contract.PresentableSurface;
const PresentableDraw = presentable_contract.PresentableDraw;
const PresentableInfo = presentable_contract.PresentableInfo;
const RendererCapabilities = capability_contract.RendererCapabilities;

fn supportsRuntimeProfileForBootstrap(profile: bootstrap_contract.RendererRuntimeProfile) bool {
    return switch (profile) {
        .backend_smoke => true,
        .full_ui => builtin.target.os.tag == .macos,
    };
}

pub fn bootstrapOps() bootstrap_contract.BackendBootstrapOps {
    return .{
        .graphics_binding = .metal,
        .supportsRuntimeProfile = supportsRuntimeProfileForBootstrap,
        .configureWindowAttributes = configureWindowAttributes,
        .runStartupSmoke = runStartupSmokeForBootstrap,
    };
}

pub fn capabilities(renderer: anytype) RendererCapabilities {
    const raw_image_textures = hasBackendContext(renderer);
    return .{
        .scene_composition_mode = .direct_main_target,
        .retained_targets = false,
        .editor_presentable_cache_compatible = true,
        .terminal_presentation_mode = .direct_snapshot_cache,
        .screenshot_mode = .present_capture,
        .text_rendering_mode = .unavailable,
        .planned_text_rendering_mode = .metal_texture_atlas,
        .kitty_image_mode = if (raw_image_textures) .direct_raw_images else .unsupported,
        .atlas_storage_mode = .metal_textures,
        .planned_atlas_storage_mode = .metal_textures,
        .raw_image_textures = raw_image_textures,
    };
}

pub fn configureRuntimePolicy(_: anytype) void {}

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

const MTLScissorRect = extern struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
};

const pixel_format_bgra8_unorm: usize = 80;
const pixel_format_r8_unorm: usize = 10;
const load_action_load: usize = 1;
const load_action_clear: usize = 2;
const store_action_store: usize = 1;
const texture_usage_shader_read: usize = 1;
const texture_usage_render_target: usize = 4;
const primitive_type_triangle_strip: usize = 4;
const blend_operation_add: usize = 0;
const blend_factor_source_alpha: usize = 4;
const blend_factor_one_minus_source_alpha: usize = 5;
const blend_factor_one: usize = 1;
const sampler_min_mag_filter_nearest: usize = 0;
const default_glyph_atlas_width: i32 = 2048;
const default_glyph_atlas_height: i32 = 2048;

const atlas_shader_source =
    "#include <metal_stdlib>\n" ++
    "using namespace metal;\n" ++
    "struct AtlasVertexIn {\n" ++
    "    float2 position;\n" ++
    "    float2 uv;\n" ++
    "};\n" ++
    "struct AtlasVertexOut {\n" ++
    "    float4 position [[position]];\n" ++
    "    float2 uv;\n" ++
    "};\n" ++
    "struct AtlasFragmentUniforms {\n" ++
    "    float4 tint;\n" ++
    "    uint alpha_only;\n" ++
    "    uint3 _padding;\n" ++
    "};\n" ++
    "vertex AtlasVertexOut zideAtlasVertex(\n" ++
    "    const device AtlasVertexIn *vertices [[buffer(0)]],\n" ++
    "    uint vertex_id [[vertex_id]]) {\n" ++
    "    AtlasVertexOut out;\n" ++
    "    out.position = float4(vertices[vertex_id].position, 0.0, 1.0);\n" ++
    "    out.uv = vertices[vertex_id].uv;\n" ++
    "    return out;\n" ++
    "}\n" ++
    "fragment float4 zideAtlasFragment(\n" ++
    "    AtlasVertexOut in [[stage_in]],\n" ++
    "    texture2d<float> atlas [[texture(0)]],\n" ++
    "    sampler atlas_sampler [[sampler(0)]],\n" ++
    "    constant AtlasFragmentUniforms &uniforms [[buffer(0)]]) {\n" ++
    "    const float4 sample = atlas.sample(atlas_sampler, in.uv);\n" ++
    "    if (uniforms.alpha_only != 0u) {\n" ++
    "        return float4(uniforms.tint.rgb, uniforms.tint.a * sample.r);\n" ++
    "    }\n" ++
    "    return sample * uniforms.tint;\n" ++
    "}\n" ++
    "\x00";

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

pub const AtlasTextureSource = surface_draw.AtlasTextureSource;
pub const AtlasSampleDraw = surface_draw.AtlasSampleDraw;
pub const GpuImageRef = surface_draw.GpuImageRef;
pub const RawImageDraw = surface_draw.RawImageDraw;
pub const SolidColorDraw = surface_draw.SolidColorDraw;
const SurfaceDraw = surface_draw.SurfaceDraw;

pub const BackendContext = struct {
    host: macos_metal_host.Host,
    metal_layer: *anyopaque,
    device: *anyopaque,
    command_queue: *anyopaque,
    atlas_pipeline: *anyopaque,
    atlas_sampler: *anyopaque,
    glyph_atlas: GlyphAtlas,
    terminal_snapshot: ?GpuImageRef,
    terminal_snapshot_scratch: ?GpuImageRef,
    /// 1×1 white texture for tint-only solid fills (cursor, rects).
    solid_white_brush: ?GpuImageRef,
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

fn ptrFromGpuImageHandle(texture: GpuImageRef) ?*anyopaque {
    if (texture.handle == 0) return null;
    return @ptrFromInt(texture.handle);
}

pub fn prepareHost(renderer: anytype) ?macos_metal_host.Host {
    return switch (renderer.render_surface_attachment) {
        .macos_metal_host => |host| host,
        else => null,
    };
}

pub fn createBackendContextForRenderer(renderer: anytype) ?BackendContext {
    const host = prepareHost(renderer) orelse return null;
    return createBackendContext(host, renderer.render_width, renderer.render_height);
}

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

fn msgSendSetScissorRect(target: *anyopaque, selector_name: [*:0]const u8, value: MTLScissorRect) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, MTLScissorRect) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
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

fn msgSendStringArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value: [*:0]const u8) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, [*:0]const u8) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value);
}

fn msgSendPointerPointerPointerArgPointer(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    value0: *anyopaque,
    value1: ?*anyopaque,
    value2: *?*anyopaque,
) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque, ?*anyopaque, *?*anyopaque) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value0, value1, value2);
}

fn msgSendPointerErrorArgPointer(
    target: *anyopaque,
    selector_name: [*:0]const u8,
    value0: *anyopaque,
    value1: *?*anyopaque,
) ?*anyopaque {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque, *?*anyopaque) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, sel, value0, value1);
}

fn msgSendPointerArgU64Void(target: *anyopaque, selector_name: [*:0]const u8, value0: *anyopaque, value1: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value0, value1);
}

fn msgSendBytesU64U64Void(target: *anyopaque, selector_name: [*:0]const u8, bytes: *const anyopaque, length: usize, index: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *const anyopaque, usize, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, bytes, length, index);
}

fn msgSendSetBoolU64(target: *anyopaque, selector_name: [*:0]const u8, value0: bool, value1: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, bool, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value0, value1);
}

fn msgSendSetU64U64(target: *anyopaque, selector_name: [*:0]const u8, value0: usize, value1: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value0, value1);
}

fn msgSendSetPointerU64(target: *anyopaque, selector_name: [*:0]const u8, value0: *anyopaque, value1: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value0, value1);
}

fn msgSendSetU64U64U64Void(target: *anyopaque, selector_name: [*:0]const u8, value0: usize, value1: usize, value2: usize) void {
    const sel = objc.sel_registerName(selector_name);
    const fn_ptr: *const fn (*anyopaque, objc.SEL, usize, usize, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, sel, value0, value1, value2);
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
    msgSendSetU64(descriptor, "setUsage:", texture_usage_shader_read | texture_usage_render_target);
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

fn atlasTexture(atlas: *const GlyphAtlas, source: AtlasTextureSource) *const AtlasTexture {
    return switch (source) {
        .coverage => &atlas.coverage,
        .color => &atlas.color,
    };
}

fn nsString(string: [*:0]const u8) ?*anyopaque {
    const nsstring_class = classPointer("NSString") orelse return null;
    return msgSendStringArgPointer(nsstring_class, "stringWithUTF8String:", string);
}

fn createAtlasPipeline(device: *anyopaque) ?*anyopaque {
    if (builtin.target.os.tag != .macos) return null;
    const source = nsString(atlas_shader_source) orelse return null;
    var compile_error: ?*anyopaque = null;
    const library = msgSendPointerPointerPointerArgPointer(
        device,
        "newLibraryWithSource:options:error:",
        source,
        null,
        &compile_error,
    ) orelse return null;
    defer releaseObject(library);

    const vertex_name = nsString("zideAtlasVertex") orelse return null;
    const fragment_name = nsString("zideAtlasFragment") orelse return null;
    const vertex_fn = msgSendPointerArgPointer(library, "newFunctionWithName:", vertex_name) orelse return null;
    defer releaseObject(vertex_fn);
    const fragment_fn = msgSendPointerArgPointer(library, "newFunctionWithName:", fragment_name) orelse return null;
    defer releaseObject(fragment_fn);

    const descriptor_class = classPointer("MTLRenderPipelineDescriptor") orelse return null;
    const descriptor = msgSendPointer(descriptor_class, "new") orelse return null;
    defer releaseObject(descriptor);

    msgSendSetPointer(descriptor, "setVertexFunction:", vertex_fn);
    msgSendSetPointer(descriptor, "setFragmentFunction:", fragment_fn);

    const color_attachments = msgSendPointer(descriptor, "colorAttachments") orelse return null;
    const color_attachment = msgSendU64ArgPointer(color_attachments, "objectAtIndexedSubscript:", 0) orelse return null;
    msgSendSetU64(color_attachment, "setPixelFormat:", pixel_format_bgra8_unorm);
    msgSendSetBool(color_attachment, "setBlendingEnabled:", true);
    msgSendSetU64(color_attachment, "setRgbBlendOperation:", blend_operation_add);
    msgSendSetU64(color_attachment, "setAlphaBlendOperation:", blend_operation_add);
    msgSendSetU64(color_attachment, "setSourceRGBBlendFactor:", blend_factor_source_alpha);
    msgSendSetU64(color_attachment, "setDestinationRGBBlendFactor:", blend_factor_one_minus_source_alpha);
    msgSendSetU64(color_attachment, "setSourceAlphaBlendFactor:", blend_factor_one);
    msgSendSetU64(color_attachment, "setDestinationAlphaBlendFactor:", blend_factor_one_minus_source_alpha);

    var pipeline_error: ?*anyopaque = null;
    return msgSendPointerErrorArgPointer(
        device,
        "newRenderPipelineStateWithDescriptor:error:",
        descriptor,
        &pipeline_error,
    );
}

fn createAtlasSampler(device: *anyopaque) ?*anyopaque {
    if (builtin.target.os.tag != .macos) return null;
    const descriptor_class = classPointer("MTLSamplerDescriptor") orelse return null;
    const descriptor = msgSendPointer(descriptor_class, "new") orelse return null;
    defer releaseObject(descriptor);
    msgSendSetU64(descriptor, "setMinFilter:", sampler_min_mag_filter_nearest);
    msgSendSetU64(descriptor, "setMagFilter:", sampler_min_mag_filter_nearest);
    return msgSendPointerArgPointer(device, "newSamplerStateWithDescriptor:", descriptor);
}

fn encodeAtlasTextureRegion(
    context: *BackendContext,
    frame: *Frame,
    source: AtlasTextureSource,
    source_rect: types.Rect,
    dest_x: i32,
    dest_y: i32,
    tint: types.Rgba,
    clip_rect: ?PixelClipRect,
) bool {
    if (builtin.target.os.tag != .macos) return false;
    const drawable_texture = msgSendPointer(frame.drawable, "texture") orelse return false;
    const width: i32 = @intFromFloat(source_rect.width);
    const height: i32 = @intFromFloat(source_rect.height);
    if (width <= 0 or height <= 0) return false;
    if (context.drawable_width <= 0 or context.drawable_height <= 0) return false;

    const render_pass_descriptor_class = classPointer("MTLRenderPassDescriptor") orelse return false;
    const render_pass_descriptor = msgSendClassPointer(render_pass_descriptor_class, "renderPassDescriptor") orelse return false;
    const color_attachments = msgSendPointer(render_pass_descriptor, "colorAttachments") orelse return false;
    const color_attachment = msgSendU64ArgPointer(color_attachments, "objectAtIndexedSubscript:", 0) orelse return false;
    msgSendSetPointer(color_attachment, "setTexture:", drawable_texture);
    msgSendSetU64(color_attachment, "setLoadAction:", load_action_load);
    msgSendSetU64(color_attachment, "setStoreAction:", store_action_store);

    const encoder = msgSendPointerArgPointer(frame.command_buffer, "renderCommandEncoderWithDescriptor:", render_pass_descriptor) orelse return false;
    defer msgSendVoid(encoder, "endEncoding");

    msgSendSetPointer(encoder, "setRenderPipelineState:", context.atlas_pipeline);
    msgSendPointerArgU64Void(encoder, "setFragmentSamplerState:atIndex:", context.atlas_sampler, 0);
    msgSendSetPointerU64(encoder, "setFragmentTexture:atIndex:", atlasTexture(&context.glyph_atlas, source).texture, 0);

    if (clip_rect) |rect| {
        const clip_x0 = @max(0, @min(rect.x, context.drawable_width));
        const clip_y0 = @max(0, @min(rect.y, context.drawable_height));
        const clip_x1 = @max(clip_x0, @min(rect.x + rect.width, context.drawable_width));
        const clip_y1 = @max(clip_y0, @min(rect.y + rect.height, context.drawable_height));
        const clip_w = clip_x1 - clip_x0;
        const clip_h = clip_y1 - clip_y0;
        if (clip_w <= 0 or clip_h <= 0) return false;
        msgSendSetScissorRect(encoder, "setScissorRect:", .{
            .x = @intCast(clip_x0),
            .y = @intCast(clip_y0),
            .width = @intCast(clip_w),
            .height = @intCast(clip_h),
        });
    }

    const atlas = atlasTexture(&context.glyph_atlas, source);
    const dest_x0 = @as(f32, @floatFromInt(dest_x));
    const dest_y0 = @as(f32, @floatFromInt(dest_y));
    const dest_x1 = dest_x0 + @as(f32, @floatFromInt(width));
    const dest_y1 = dest_y0 + @as(f32, @floatFromInt(height));
    const drawable_w = @as(f32, @floatFromInt(context.drawable_width));
    const drawable_h = @as(f32, @floatFromInt(context.drawable_height));
    const src_x0 = source_rect.x / @as(f32, @floatFromInt(atlas.width));
    const src_y0 = source_rect.y / @as(f32, @floatFromInt(atlas.height));
    const src_x1 = (source_rect.x + source_rect.width) / @as(f32, @floatFromInt(atlas.width));
    const src_y1 = (source_rect.y + source_rect.height) / @as(f32, @floatFromInt(atlas.height));

    const vertices = [_]AtlasVertex{
        .{
            .position = .{ (dest_x0 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y0 / drawable_h) * 2.0 },
            .uv = .{ src_x0, src_y0 },
        },
        .{
            .position = .{ (dest_x1 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y0 / drawable_h) * 2.0 },
            .uv = .{ src_x1, src_y0 },
        },
        .{
            .position = .{ (dest_x0 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y1 / drawable_h) * 2.0 },
            .uv = .{ src_x0, src_y1 },
        },
        .{
            .position = .{ (dest_x1 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y1 / drawable_h) * 2.0 },
            .uv = .{ src_x1, src_y1 },
        },
    };
    const fragment_uniforms = AtlasFragmentUniforms{
        .tint = .{
            @as(f32, @floatFromInt(tint.r)) / 255.0,
            @as(f32, @floatFromInt(tint.g)) / 255.0,
            @as(f32, @floatFromInt(tint.b)) / 255.0,
            @as(f32, @floatFromInt(tint.a)) / 255.0,
        },
        .alpha_only = if (source == .coverage) 1 else 0,
    };
    msgSendBytesU64U64Void(
        encoder,
        "setVertexBytes:length:atIndex:",
        @ptrCast(&vertices),
        @sizeOf(@TypeOf(vertices)),
        0,
    );
    msgSendBytesU64U64Void(
        encoder,
        "setFragmentBytes:length:atIndex:",
        @ptrCast(&fragment_uniforms),
        @sizeOf(AtlasFragmentUniforms),
        0,
    );
    msgSendSetU64U64U64Void(encoder, "drawPrimitives:vertexStart:vertexCount:", primitive_type_triangle_strip, 0, 4);
    return true;
}

fn encodeExternalTextureRegion(
    context: *BackendContext,
    frame: *Frame,
    texture: *anyopaque,
    texture_width: i32,
    texture_height: i32,
    source_rect: types.Rect,
    dest_rect: types.Rect,
    tint: types.Rgba,
    clip_rect: ?PixelClipRect,
) bool {
    if (builtin.target.os.tag != .macos) return false;
    const drawable_texture = msgSendPointer(frame.drawable, "texture") orelse return false;
    const width: i32 = @intFromFloat(source_rect.width);
    const height: i32 = @intFromFloat(source_rect.height);
    if (width <= 0 or height <= 0) return false;
    if (context.drawable_width <= 0 or context.drawable_height <= 0) return false;

    const render_pass_descriptor_class = classPointer("MTLRenderPassDescriptor") orelse return false;
    const render_pass_descriptor = msgSendClassPointer(render_pass_descriptor_class, "renderPassDescriptor") orelse return false;
    const color_attachments = msgSendPointer(render_pass_descriptor, "colorAttachments") orelse return false;
    const color_attachment = msgSendU64ArgPointer(color_attachments, "objectAtIndexedSubscript:", 0) orelse return false;
    msgSendSetPointer(color_attachment, "setTexture:", drawable_texture);
    msgSendSetU64(color_attachment, "setLoadAction:", load_action_load);
    msgSendSetU64(color_attachment, "setStoreAction:", store_action_store);

    const encoder = msgSendPointerArgPointer(frame.command_buffer, "renderCommandEncoderWithDescriptor:", render_pass_descriptor) orelse return false;
    defer msgSendVoid(encoder, "endEncoding");

    msgSendSetPointer(encoder, "setRenderPipelineState:", context.atlas_pipeline);
    msgSendPointerArgU64Void(encoder, "setFragmentSamplerState:atIndex:", context.atlas_sampler, 0);
    msgSendSetPointerU64(encoder, "setFragmentTexture:atIndex:", texture, 0);

    if (clip_rect) |rect| {
        const clip_x0 = @max(0, @min(rect.x, context.drawable_width));
        const clip_y0 = @max(0, @min(rect.y, context.drawable_height));
        const clip_x1 = @max(clip_x0, @min(rect.x + rect.width, context.drawable_width));
        const clip_y1 = @max(clip_y0, @min(rect.y + rect.height, context.drawable_height));
        const clip_w = clip_x1 - clip_x0;
        const clip_h = clip_y1 - clip_y0;
        if (clip_w <= 0 or clip_h <= 0) return false;
        msgSendSetScissorRect(encoder, "setScissorRect:", .{
            .x = @intCast(clip_x0),
            .y = @intCast(clip_y0),
            .width = @intCast(clip_w),
            .height = @intCast(clip_h),
        });
    }

    const dest_x0 = dest_rect.x;
    const dest_y0 = dest_rect.y;
    const dest_x1 = dest_rect.x + dest_rect.width;
    const dest_y1 = dest_rect.y + dest_rect.height;
    const drawable_w = @as(f32, @floatFromInt(context.drawable_width));
    const drawable_h = @as(f32, @floatFromInt(context.drawable_height));
    const src_x0 = source_rect.x / @as(f32, @floatFromInt(texture_width));
    const src_y0 = source_rect.y / @as(f32, @floatFromInt(texture_height));
    const src_x1 = (source_rect.x + source_rect.width) / @as(f32, @floatFromInt(texture_width));
    const src_y1 = (source_rect.y + source_rect.height) / @as(f32, @floatFromInt(texture_height));

    const vertices = [_]AtlasVertex{
        .{
            .position = .{ (dest_x0 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y0 / drawable_h) * 2.0 },
            .uv = .{ src_x0, src_y0 },
        },
        .{
            .position = .{ (dest_x1 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y0 / drawable_h) * 2.0 },
            .uv = .{ src_x1, src_y0 },
        },
        .{
            .position = .{ (dest_x0 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y1 / drawable_h) * 2.0 },
            .uv = .{ src_x0, src_y1 },
        },
        .{
            .position = .{ (dest_x1 / drawable_w) * 2.0 - 1.0, 1.0 - (dest_y1 / drawable_h) * 2.0 },
            .uv = .{ src_x1, src_y1 },
        },
    };
    const fragment_uniforms = AtlasFragmentUniforms{
        .tint = .{
            @as(f32, @floatFromInt(tint.r)) / 255.0,
            @as(f32, @floatFromInt(tint.g)) / 255.0,
            @as(f32, @floatFromInt(tint.b)) / 255.0,
            @as(f32, @floatFromInt(tint.a)) / 255.0,
        },
        .alpha_only = 0,
    };
    msgSendBytesU64U64Void(
        encoder,
        "setVertexBytes:length:atIndex:",
        @ptrCast(&vertices),
        @sizeOf(@TypeOf(vertices)),
        0,
    );
    msgSendBytesU64U64Void(
        encoder,
        "setFragmentBytes:length:atIndex:",
        @ptrCast(&fragment_uniforms),
        @sizeOf(AtlasFragmentUniforms),
        0,
    );
    msgSendSetU64U64U64Void(encoder, "drawPrimitives:vertexStart:vertexCount:", primitive_type_triangle_strip, 0, 4);
    return true;
}

pub fn drawAtlasSample(
    context: *BackendContext,
    frame: *Frame,
    sample: AtlasSampleDraw,
) bool {
    return encodeAtlasTextureRegion(
        context,
        frame,
        sample.atlas,
        sample.source_rect,
        sample.dest_x,
        sample.dest_y,
        sample.tint,
        sample.clip_rect,
    );
}

pub fn drawRawImage(
    context: *BackendContext,
    frame: *Frame,
    draw: RawImageDraw,
) bool {
    const texture_ptr = ptrFromGpuImageHandle(draw.texture) orelse return false;
    const source_rect = draw.source_rect orelse types.Rect{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(draw.texture.width),
        .height = @floatFromInt(draw.texture.height),
    };
    return encodeExternalTextureRegion(
        context,
        frame,
        texture_ptr,
        draw.texture.width,
        draw.texture.height,
        source_rect,
        draw.dest_rect,
        draw.tint,
        draw.clip_rect,
    );
}

pub fn drawSolidColor(
    context: *BackendContext,
    frame: *Frame,
    draw: SolidColorDraw,
) bool {
    const brush = context.solid_white_brush orelse return false;
    const brush_ptr = ptrFromGpuImageHandle(brush) orelse return false;
    return encodeExternalTextureRegion(
        context,
        frame,
        brush_ptr,
        brush.width,
        brush.height,
        .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(brush.width),
            .height = @floatFromInt(brush.height),
        },
        draw.dest_rect,
        draw.color,
        draw.clip_rect,
    );
}

pub fn releaseGpuImageRef(texture: *GpuImageRef) void {
    if (builtin.target.os.tag != .macos) return;
    if (texture.handle == 0) return;
    if (ptrFromGpuImageHandle(texture.*)) |ptr| releaseObject(ptr);
    texture.* = .{ .handle = 0, .width = 0, .height = 0 };
}

pub fn cloneGpuImageRef(texture: GpuImageRef) GpuImageRef {
    if (ptrFromGpuImageHandle(texture)) |ptr| {
        _ = retainObject(ptr);
    }
    return texture;
}

fn createEmptyRawImageTexture(
    device: *anyopaque,
    width: i32,
    height: i32,
) ?GpuImageRef {
    if (builtin.target.os.tag != .macos) return null;
    const atlas_texture = createAtlasTexture(device, width, height, pixel_format_bgra8_unorm) orelse return null;
    return .{
        .handle = @intFromPtr(atlas_texture.texture),
        .width = width,
        .height = height,
    };
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

pub fn createRawImageTextureRgba(
    device: *anyopaque,
    width: i32,
    height: i32,
    data: []const u8,
) ?GpuImageRef {
    if (builtin.target.os.tag != .macos) return null;
    const atlas_texture = createAtlasTexture(device, width, height, pixel_format_bgra8_unorm) orelse return null;
    errdefer releaseObject(atlas_texture.texture);
    const converted = std.heap.page_allocator.alloc(u8, data.len) catch return null;
    defer std.heap.page_allocator.free(converted);
    var idx: usize = 0;
    while (idx + 3 < data.len) : (idx += 4) {
        converted[idx + 0] = data[idx + 2];
        converted[idx + 1] = data[idx + 1];
        converted[idx + 2] = data[idx + 0];
        converted[idx + 3] = data[idx + 3];
    }
    const uploaded = uploadAtlasTexture(
        &atlas_texture,
        .{ .x = 0, .y = 0, .width = @floatFromInt(width), .height = @floatFromInt(height) },
        4,
        converted,
    );
    if (!uploaded) return null;
    return .{
        .handle = @intFromPtr(atlas_texture.texture),
        .width = width,
        .height = height,
    };
}

pub fn createRawImageTextureRgb(
    device: *anyopaque,
    width: i32,
    height: i32,
    data: []const u8,
) ?GpuImageRef {
    if (builtin.target.os.tag != .macos) return null;
    const atlas_texture = createAtlasTexture(device, width, height, pixel_format_bgra8_unorm) orelse return null;
    errdefer releaseObject(atlas_texture.texture);
    const converted_len: usize = @intCast(width * height * 4);
    const converted = std.heap.page_allocator.alloc(u8, converted_len) catch return null;
    defer std.heap.page_allocator.free(converted);
    var src_idx: usize = 0;
    var dst_idx: usize = 0;
    while (src_idx + 2 < data.len and dst_idx + 3 < converted.len) : ({
        src_idx += 3;
        dst_idx += 4;
    }) {
        converted[dst_idx + 0] = data[src_idx + 2];
        converted[dst_idx + 1] = data[src_idx + 1];
        converted[dst_idx + 2] = data[src_idx + 0];
        converted[dst_idx + 3] = 0xFF;
    }
    const uploaded = uploadAtlasTexture(
        &atlas_texture,
        .{ .x = 0, .y = 0, .width = @floatFromInt(width), .height = @floatFromInt(height) },
        4,
        converted,
    );
    if (!uploaded) return null;
    return .{
        .handle = @intFromPtr(atlas_texture.texture),
        .width = width,
        .height = height,
    };
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
    errdefer releaseObject(command_queue);
    const atlas_pipeline = createAtlasPipeline(device) orelse {
        releaseObject(device);
        return null;
    };
    errdefer releaseObject(atlas_pipeline);
    const atlas_sampler = createAtlasSampler(device) orelse {
        releaseObject(atlas_pipeline);
        releaseObject(device);
        return null;
    };
    errdefer releaseObject(atlas_sampler);
    const glyph_atlas = createGlyphAtlas(device, default_glyph_atlas_width, default_glyph_atlas_height) orelse {
        return null;
    };
    const solid_white = [_]u8{ 255, 255, 255, 255 };
    const solid_white_brush = createRawImageTextureRgba(device, 1, 1, &solid_white);
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
        .atlas_pipeline = atlas_pipeline,
        .atlas_sampler = atlas_sampler,
        .glyph_atlas = glyph_atlas,
        .terminal_snapshot = null,
        .terminal_snapshot_scratch = null,
        .solid_white_brush = solid_white_brush,
        .drawable_width = drawable_width,
        .drawable_height = drawable_height,
    };
}

pub fn initRuntime(renderer: anytype) !void {
    const metal_runtime_ok = renderer.runtime_profile == .backend_smoke or
        (renderer.runtime_profile == .full_ui and builtin.target.os.tag == .macos);
    if (!metal_runtime_ok) return error.RendererBackendRuntimeNotReady;
    const host = prepareHost(renderer) orelse return error.MacosMetalAttachmentUnavailable;
    renderer.backend_runtime.metal.backend_context = createBackendContext(host, renderer.render_width, renderer.render_height) orelse return error.MetalBackendContextUnavailable;
    try renderer.initFonts();
    renderer.fonts_ready = true;
}

pub fn configureWindowAttributes() !void {}

pub fn runStartupSmokeForBootstrap(_: *sdl_api.c.SDL_Window, render_surface_attachment: window_init.RenderSurfaceAttachment, width: i32, height: i32) !bool {
    const host = switch (render_surface_attachment) {
        .macos_metal_host => |value| value,
        else => return false,
    };
    var context = createBackendContext(host, width, height) orelse return false;
    defer deinitBackendContext(&context);

    var frame = acquireFrame(&context) orelse return false;
    if (!clearFrame(&frame, .{ 0.08, 0.09, 0.11, 1.0 })) {
        abandonFrame(&frame);
        return false;
    }
    presentFrame(&context, &frame);
    return true;
}

pub fn beginFrame(renderer: anytype) void {
    clearQueuedSurfaceDraws(renderer);
    if (backendContext(renderer)) |context| {
        resizeBackendContext(context, renderer.render_width, renderer.render_height);
        var frame = acquireFrame(context) orelse {
            renderer.present.main_composition_target = .default_target;
            clearCurrentFrame(renderer);
            return;
        };
        const bg = renderer.theme.background.toRgba();
        const cleared = clearFrame(&frame, .{
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        });
        if (!cleared) {
            abandonFrame(&frame);
            renderer.present.main_composition_target = .default_target;
            clearCurrentFrame(renderer);
            return;
        }
        renderer.present.main_composition_target = .backend_surface;
        storeCurrentFrame(renderer, frame);
    } else {
        renderer.present.main_composition_target = .default_target;
        clearCurrentFrame(renderer);
    }
}

pub fn submitFrame(renderer: anytype) present_trace_runtime.FrameSubmission {
    defer clearQueuedSurfaceDraws(renderer);
    const present_start = sdl_api.getPerformanceCounter();
    const succeeded = if (backendContext(renderer)) |context|
        if (currentFrame(renderer)) |frame| inner: {
            var capture_readback: ?Readback = null;
            defer if (capture_readback) |*readback| deinitReadback(readback);

            if (renderer.present.capture_armed) {
                capture_readback = prepareFrameReadback(context, frame);
            }

            replayQueuedSurfaceDraws(renderer, context, frame);
            _ = captureTerminalSnapshot(context, frame);
            encodePresent(frame);
            commitFrame(frame);

            if (capture_readback) |*readback| {
                waitForFrame(frame);
                if (renderer.present.capture_path) |path| {
                    const rgba = copyReadbackRgba(renderer.allocator, readback) catch |err| rgba_capture: {
                        app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                            renderer.present.frame_seq,
                            path,
                            @errorName(err),
                        });
                        break :rgba_capture null;
                    };
                    if (rgba) |pixels| {
                        defer renderer.allocator.free(pixels);
                        screenshot.dumpRgbaPixelsPpmScaled(
                            renderer.allocator,
                            pixels,
                            readback.width,
                            readback.height,
                            renderer.width,
                            renderer.height,
                            path,
                            .top_left,
                        ) catch |err| {
                            app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                                renderer.present.frame_seq,
                                path,
                                @errorName(err),
                            });
                        };
                        renderer.present.trace_current.captured_path = path;
                    }
                }
            } else if (renderer.present.capture_armed) {
                if (renderer.present.capture_path) |path| {
                    app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err=MetalReadbackUnavailable", .{
                        renderer.present.frame_seq,
                        path,
                    });
                }
            }

            releaseFrame(frame);
            clearCurrentFrame(renderer);
            break :inner true;
        } else false
    else
        false;
    const present_end = sdl_api.getPerformanceCounter();
    return renderer_frame_host.finishFrameSubmission(
        renderer,
        succeeded,
        present_trace_runtime.performanceDeltaMs(present_start, present_end, renderer.perf_freq),
    );
}

pub fn dumpWindowScreenshotPpm(_: anytype, _: []const u8) !void {
    return error.RendererScreenshotUnavailable;
}

pub fn dumpWindowScreenshotPpmSized(_: anytype, _: []const u8, _: i32, _: i32) !void {
    return error.RendererScreenshotUnavailable;
}

pub fn clearThemeBackground(_: anytype) void {}

pub fn backendContext(renderer: anytype) ?*BackendContext {
    if (renderer.backend_runtime.metal.backend_context) |*context| return context;
    return null;
}

pub fn backendContextConst(renderer: anytype) ?*const BackendContext {
    if (renderer.backend_runtime.metal.backend_context) |*context| return context;
    return null;
}

pub fn hasBackendContext(renderer: anytype) bool {
    return backendContextConst(renderer) != null;
}

pub fn glyphAtlasReadyForRenderer(renderer: anytype) bool {
    const context = backendContextConst(renderer) orelse return false;
    return glyphAtlasReady(context);
}

pub fn atlasPreviewSourceForRenderer(renderer: anytype) AtlasPreviewSource {
    return renderer.backend_runtime.metal.preview_source;
}

pub fn runAtlasUploadDiagnosticAt(renderer: anytype, dest_x: i32, dest_y: i32) bool {
    if (!hasBackendContext(renderer)) return false;
    clearQueuedSurfaceDraws(renderer);
    renderer.backend_runtime.metal.preview_source = .unavailable;

    const font = ensureDiagnosticFont(renderer) catch return false;
    const color_preview_rect = font.uploadDiagnosticColorGlyphPreview();
    const codepoint: u32 = 'A';
    const direct = font.directFastGlyphForCodepoint(codepoint) orelse return false;
    const coverage_glyph = font.getGlyphById(direct.face, direct.glyph_id, direct.want_color, false, 0) catch return false;
    if (coverage_glyph.rect.width > 0 and coverage_glyph.rect.height > 0) {
        _ = appendAtlasSample(renderer, .{
            .atlas = .color,
            .source_rect = coverage_glyph.rect,
            .dest_x = dest_x,
            .dest_y = dest_y,
            .tint = iface.Color.white.toRgba(),
        });
        renderer.backend_runtime.metal.preview_source = .uploaded_coverage_glyph;
    }
    if (color_preview_rect) |rect| {
        clearQueuedSurfaceDraws(renderer);
        _ = appendAtlasSample(renderer, .{
            .atlas = .color,
            .source_rect = rect,
            .dest_x = dest_x,
            .dest_y = dest_y,
            .tint = iface.Color.white.toRgba(),
        });
        renderer.backend_runtime.metal.preview_source = .uploaded_color_glyph;
    } else if (queuedSurfaceDrawCount(renderer) == 0) {
        _ = appendAtlasSample(renderer, .{
            .atlas = .color,
            .source_rect = .{
                .x = 0,
                .y = 0,
                .width = 4,
                .height = 4,
            },
            .dest_x = dest_x,
            .dest_y = dest_y,
            .tint = iface.Color.white.toRgba(),
        });
        renderer.backend_runtime.metal.preview_source = .seeded_color_block;
    }
    return renderer.backend_runtime.metal.preview_source == .uploaded_coverage_glyph or
        renderer.backend_runtime.metal.preview_source == .uploaded_color_glyph;
}

pub fn terminalFontAtlasUploadHooksForRenderer(renderer: anytype) ?terminal_font.AtlasUploadHooks {
    const context = backendContext(renderer) orelse return null;
    return terminalFontAtlasUploadHooks(context);
}

fn queuedSurfaceDrawCount(renderer: anytype) usize {
    return renderer.backend_runtime.metal.queued_surface_draws.items.len;
}

fn currentFrame(renderer: anytype) ?*Frame {
    if (renderer.backend_runtime.metal.frame) |*frame| return frame;
    return null;
}

fn clearCurrentFrame(renderer: anytype) void {
    renderer.backend_runtime.metal.frame = null;
}

fn storeCurrentFrame(renderer: anytype, frame: Frame) void {
    renderer.backend_runtime.metal.frame = frame;
}

pub fn appendSurfaceDrawToMetalQueue(renderer: anytype, draw: SurfaceDraw) bool {
    renderer.backend_runtime.metal.queued_surface_draws.append(renderer.allocator, draw) catch {
        var queued_draw = draw;
        switch (queued_draw) {
            .atlas => {},
            .solid => {},
            .raw_image => |*raw| releaseGpuImageRef(&raw.texture),
        }
        return false;
    };
    return true;
}

pub fn appendSolidRect(
    renderer: anytype,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: types.Rgba,
) bool {
    const clip = if (renderer.currentClipRect()) |c|
        metal_text_sample_runtime.pixelClipRect(renderer, c)
    else
        null;
    return appendSurfaceDrawToMetalQueue(renderer, .{ .solid = .{
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(x),
            .y = renderer.logicalLengthToRaster(y),
            .width = renderer.logicalLengthToRaster(w),
            .height = renderer.logicalLengthToRaster(h),
        },
        .color = color,
        .clip_rect = clip,
    } });
}

fn appendAtlasSample(renderer: anytype, sample: AtlasSampleDraw) bool {
    return appendSurfaceDrawToMetalQueue(renderer, .{ .atlas = sample });
}

fn appendRawImage(renderer: anytype, draw: RawImageDraw) bool {
    return appendSurfaceDrawToMetalQueue(renderer, .{ .raw_image = draw });
}

pub fn addTerminalRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    _ = appendSolidRect(
        renderer,
        @floatFromInt(x),
        @floatFromInt(y),
        @floatFromInt(w),
        @floatFromInt(h),
        color,
    );
}

pub fn addTerminalGlyphRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: types.Rgba) void {
    addTerminalRect(renderer, x, y, w, h, color);
}

pub fn addTerminalGlyphQuad(
    renderer: anytype,
    texture: types.Texture,
    src: types.Rect,
    dest: types.Rect,
    color: types.Rgba,
    kind: types.TextureKind,
) void {
    _ = texture;
    const clip_rect = if (renderer.currentClipRect()) |clip|
        metal_text_sample_runtime.pixelClipRect(renderer, clip)
    else
        null;
    const atlas_kind: ?surface_draw.AtlasTextureSource = switch (kind) {
        .font_coverage => .coverage,
        .rgba => .color,
        else => null,
    };
    if (atlas_kind) |atlas| {
        _ = appendAtlasSample(renderer, .{
            .atlas = atlas,
            .source_rect = src,
            .dest_x = @intFromFloat(std.math.round(renderer.logicalLengthToRaster(dest.x))),
            .dest_y = @intFromFloat(std.math.round(renderer.logicalLengthToRaster(dest.y))),
            .tint = color,
            .clip_rect = clip_rect,
        });
    }
}

pub fn applyClipRect(_: anytype, _: ?types.Rect) void {}

pub fn drawAtlasSampleChar(renderer: anytype, char: u8, x: f32, y: f32, color: iface.Color) bool {
    if (renderer.plannedTextRenderingMode() != .metal_texture_atlas) return false;
    if (!hasBackendContext(renderer)) return false;

    const font = ensureDiagnosticFont(renderer) catch return false;
    const codepoint: u32 = char;
    const clip = if (renderer.currentClipRect()) |c| metal_text_sample_runtime.pixelClipRect(renderer, c) else null;
    const sample = metal_text_sample_runtime.atlasSampleForGlyph(renderer, font, codepoint, x, y, color.toRgba(), clip) orelse return false;
    return appendAtlasSample(renderer, sample);
}

pub fn drawSampleTextRequest(
    renderer: anytype,
    request: metal_text_sample_runtime.SampleTextRequest,
) bool {
    if (renderer.plannedTextRenderingMode() != .metal_texture_atlas) return false;
    if (!hasBackendContext(renderer)) return false;

    const font = ensureDiagnosticFont(renderer) catch return false;
    return appendSampleTextRequest(renderer, font, request);
}

fn appendSampleTextRequest(
    renderer: anytype,
    font: *terminal_font.TerminalFont,
    request: metal_text_sample_runtime.SampleTextRequest,
) bool {
    return metal_text_sample_runtime.appendUtf8Run(
        renderer,
        font,
        request,
        &renderer.backend_runtime.metal.queued_surface_draws,
        renderer.allocator,
    );
}

pub fn drawTerminalCellRun(
    renderer: anytype,
    font: *terminal_font.TerminalFont,
    request: metal_text_sample_runtime.TerminalCellRunRequest,
) bool {
    if (renderer.plannedTextRenderingMode() != .metal_texture_atlas) return false;
    if (!hasBackendContext(renderer)) return false;
    return appendTerminalCellRun(renderer, font, request);
}

fn appendTerminalCellRun(
    renderer: anytype,
    font: *terminal_font.TerminalFont,
    request: metal_text_sample_runtime.TerminalCellRunRequest,
) bool {
    return metal_text_sample_runtime.appendTerminalUtf8Cells(
        renderer,
        font,
        request,
        &renderer.backend_runtime.metal.queued_surface_draws,
        renderer.allocator,
    );
}

fn appendRawImageRgba(
    renderer: anytype,
    width: i32,
    height: i32,
    data: []const u8,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    const context = backendContext(renderer) orelse return false;
    if (width <= 0 or height <= 0) return false;
    const texture = createRawImageTextureRgba(context.device, width, height, data) orelse return false;
    const clip_rect = if (renderer.currentClipRect()) |clip|
        metal_text_sample_runtime.pixelClipRect(renderer, clip)
    else
        null;
    return appendRawImage(renderer, .{
        .texture = texture,
        .source_rect = null,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = clip_rect,
    });
}

pub fn drawRawImageRgba(
    renderer: anytype,
    width: i32,
    height: i32,
    data: []const u8,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    return appendRawImageRgba(renderer, width, height, data, dest, tint);
}

fn appendRawImageRgb(
    renderer: anytype,
    width: i32,
    height: i32,
    data: []const u8,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    const context = backendContext(renderer) orelse return false;
    if (width <= 0 or height <= 0) return false;
    const texture = createRawImageTextureRgb(context.device, width, height, data) orelse return false;
    const clip_rect = if (renderer.currentClipRect()) |clip|
        metal_text_sample_runtime.pixelClipRect(renderer, clip)
    else
        null;
    return appendRawImage(renderer, .{
        .texture = texture,
        .source_rect = null,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = clip_rect,
    });
}

pub fn drawRawImageRgb(
    renderer: anytype,
    width: i32,
    height: i32,
    data: []const u8,
    dest: types.Rect,
    tint: types.Rgba,
) bool {
    return appendRawImageRgb(renderer, width, height, data, dest, tint);
}

pub fn createPersistentImageFromRgba(_: anytype, _: i32, _: i32, _: []const u8) ?GpuImageRef {
    return null;
}

pub fn createPersistentImageFromRgb(_: anytype, _: i32, _: i32, _: []const u8) ?GpuImageRef {
    return null;
}

pub fn destroyPersistentImage(_: anytype, _: *GpuImageRef) void {}

pub fn drawPersistentImage(renderer: anytype, texture: GpuImageRef, source_rect: ?types.Rect, dest: types.Rect, tint: types.Rgba) bool {
    return appendRawImage(renderer, .{
        .texture = cloneGpuImageRef(texture),
        .source_rect = source_rect,
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(dest.x),
            .y = renderer.logicalLengthToRaster(dest.y),
            .width = renderer.logicalLengthToRaster(dest.width),
            .height = renderer.logicalLengthToRaster(dest.height),
        },
        .tint = tint,
        .clip_rect = if (renderer.currentClipRect()) |clip_logical|
            metal_text_sample_runtime.pixelClipRect(renderer, clip_logical)
        else
            null,
    });
}

pub fn runSmokeFrame(renderer: anytype) bool {
    const host = prepareHost(renderer) orelse return false;
    var context = createBackendContext(host, renderer.render_width, renderer.render_height) orelse return false;
    defer deinitBackendContext(&context);

    var frame = acquireFrame(&context) orelse return false;
    const bg = renderer.theme.background.toRgba();
    const cleared = clearFrame(&frame, .{
        @as(f32, @floatFromInt(bg.r)) / 255.0,
        @as(f32, @floatFromInt(bg.g)) / 255.0,
        @as(f32, @floatFromInt(bg.b)) / 255.0,
        @as(f32, @floatFromInt(bg.a)) / 255.0,
    });
    if (!cleared) {
        abandonFrame(&frame);
        return false;
    }
    presentFrame(&context, &frame);
    return true;
}

fn replayQueuedSurfaceDraws(renderer: anytype, context: *BackendContext, frame: *Frame) void {
    for (renderer.backend_runtime.metal.queued_surface_draws.items) |queued_draw| {
        switch (queued_draw) {
            .atlas => |sample| _ = drawAtlasSample(context, frame, sample),
            .solid => |solid| _ = drawSolidColor(context, frame, solid),
            .raw_image => |draw| _ = drawRawImage(context, frame, draw),
        }
    }
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
    if (context.terminal_snapshot) |*snapshot| releaseGpuImageRef(snapshot);
    if (context.terminal_snapshot_scratch) |*scratch| releaseGpuImageRef(scratch);
    if (context.solid_white_brush) |*brush| releaseGpuImageRef(brush);
    context.terminal_snapshot_scratch = null;
    context.solid_white_brush = null;
    deinitGlyphAtlas(&context.glyph_atlas);
    releaseObject(context.atlas_sampler);
    releaseObject(context.atlas_pipeline);
    releaseObject(context.command_queue);
    msgSendVoid(context.device, "release");
}

pub fn deinitRuntime(renderer: anytype) void {
    clearDiagnosticFont(renderer);
    clearQueuedSurfaceDraws(renderer);
    renderer.backend_runtime.metal.queued_surface_draws.deinit(renderer.allocator);
    if (renderer.backend_runtime.metal.frame) |*frame| abandonFrame(frame);
    if (renderer.backend_runtime.metal.backend_context) |*context| deinitBackendContext(context);
}

pub fn clearDiagnosticFont(renderer: anytype) void {
    if (renderer.backend_runtime.metal.diagnostic_font) |*font| {
        font.deinit();
        renderer.backend_runtime.metal.diagnostic_font = null;
    }
}

pub fn ensureDiagnosticFont(renderer: anytype) !*terminal_font.TerminalFont {
    if (!hasBackendContext(renderer)) return error.MetalBackendContextUnavailable;
    if (renderer.backend_runtime.metal.diagnostic_font) |*font| return font;

    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const raster_size = renderer.base_font_size * render_scale;
    var font = try terminal_font.TerminalFont.initWithAtlasUploadHooks(
        renderer.allocator,
        renderer.font_config.app_font_path,
        raster_size,
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        renderer.font_config.font_rendering,
        terminalFontAtlasUploadHooksForRenderer(renderer) orelse return error.MetalBackendContextUnavailable,
    );
    font.render_scale = render_scale;
    renderer.backend_runtime.metal.diagnostic_font = font;
    return &renderer.backend_runtime.metal.diagnostic_font.?;
}

fn clearQueuedSurfaceDraws(renderer: anytype) void {
    for (renderer.backend_runtime.metal.queued_surface_draws.items) |*queued_draw| {
        switch (queued_draw.*) {
            .atlas => {},
            .solid => {},
            .raw_image => |*draw| releaseGpuImageRef(&draw.texture),
        }
    }
    renderer.backend_runtime.metal.queued_surface_draws.clearRetainingCapacity();
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

pub const EnsureTerminalSnapshotResult = struct {
    available: bool = false,
    recreated: bool = false,
};

pub fn terminalSnapshotMatchesDrawable(context: *const BackendContext) bool {
    const snap = context.terminal_snapshot orelse return false;
    return context.drawable_width > 0 and
        context.drawable_height > 0 and
        snap.width == context.drawable_width and
        snap.height == context.drawable_height;
}

pub fn ensureTerminalSnapshotPresentable(
    context: *BackendContext,
    width: i32,
    height: i32,
) EnsureTerminalSnapshotResult {
    if (width <= 0 or height <= 0) return .{};
    if (context.terminal_snapshot) |snapshot| {
        const matches = snapshot.width == width and snapshot.height == height;
        if (matches) {
            return .{
                .available = true,
                .recreated = false,
            };
        }
        var existing = snapshot;
        releaseGpuImageRef(&existing);
        context.terminal_snapshot = null;
    }
    context.terminal_snapshot = createEmptyRawImageTexture(context.device, width, height);
    const available = context.terminal_snapshot != null;
    return .{
        .available = available,
        .recreated = available,
    };
}

fn ensureTerminalSnapshotScratch(
    context: *BackendContext,
    width: i32,
    height: i32,
) bool {
    if (width <= 0 or height <= 0) return false;
    if (context.terminal_snapshot_scratch) |scratch| {
        const matches = switch (scratch) {
            .metal => |m| m.width == width and m.height == height,
            .opengl => false,
        };
        if (matches) return true;
        var existing = scratch;
        releaseGpuImageRef(&existing);
        context.terminal_snapshot_scratch = null;
    }
    context.terminal_snapshot_scratch = createEmptyRawImageTexture(context.device, width, height);
    return context.terminal_snapshot_scratch != null;
}

pub fn scrollTerminalSnapshotPresentable(
    context: *BackendContext,
    dx: i32,
    dy: i32,
) bool {
    if (builtin.target.os.tag != .macos) return false;
    if (dx == 0 and dy == 0) return true;
    if (!terminalSnapshotMatchesDrawable(context)) return false;

    const width = context.drawable_width;
    const height = context.drawable_height;
    if (width <= 0 or height <= 0) return false;
    if (@abs(dx) >= width or @abs(dy) >= height) return false;
    if (!ensureTerminalSnapshotScratch(context, width, height)) return false;

    const snapshot = context.terminal_snapshot orelse return false;
    const scratch = context.terminal_snapshot_scratch orelse return false;
    const snap_m = switch (snapshot) {
        .metal => |m| m,
        .opengl => return false,
    };
    const scratch_m = switch (scratch) {
        .metal => |m| m,
        .opengl => return false,
    };

    const src_x = @max(0, -dx);
    const src_y = @max(0, -dy);
    const dst_x = @max(0, dx);
    const dst_y = @max(0, dy);
    const abs_dx: i32 = @intCast(@abs(dx));
    const abs_dy: i32 = @intCast(@abs(dy));
    const copy_width = width - abs_dx;
    const copy_height = height - abs_dy;
    if (copy_width <= 0 or copy_height <= 0) return false;

    const command_buffer_unretained = msgSendPointer(context.command_queue, "commandBuffer") orelse return false;
    const command_buffer = retainObject(command_buffer_unretained);
    defer releaseObject(command_buffer);

    const blit_encoder = msgSendPointer(command_buffer, "blitCommandEncoder") orelse return false;
    msgSendCopyTextureToTexture(
        blit_encoder,
        "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
        snap_m.texture,
        0,
        0,
        .{ .x = @intCast(src_x), .y = @intCast(src_y), .z = 0 },
        .{
            .width = @intCast(copy_width),
            .height = @intCast(copy_height),
            .depth = 1,
        },
        scratch_m.texture,
        0,
        0,
        .{ .x = @intCast(dst_x), .y = @intCast(dst_y), .z = 0 },
    );
    msgSendCopyTextureToTexture(
        blit_encoder,
        "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
        scratch_m.texture,
        0,
        0,
        .{ .x = @intCast(dst_x), .y = @intCast(dst_y), .z = 0 },
        .{
            .width = @intCast(copy_width),
            .height = @intCast(copy_height),
            .depth = 1,
        },
        snap_m.texture,
        0,
        0,
        .{ .x = @intCast(dst_x), .y = @intCast(dst_y), .z = 0 },
    );
    msgSendVoid(blit_encoder, "endEncoding");
    msgSendVoid(command_buffer, "commit");
    msgSendVoid(command_buffer, "waitUntilCompleted");
    return true;
}

pub fn captureTerminalSnapshot(context: *BackendContext, frame: *Frame) bool {
    if (builtin.target.os.tag != .macos) return false;
    if (context.drawable_width <= 0 or context.drawable_height <= 0) return false;
    if (!ensureTerminalSnapshotPresentable(context, context.drawable_width, context.drawable_height).available) return false;
    const snapshot = context.terminal_snapshot orelse return false;
    const snap_m = switch (snapshot) {
        .metal => |m| m,
        .opengl => return false,
    };
    const source_texture = msgSendPointer(frame.drawable, "texture") orelse return false;
    const blit_encoder = msgSendPointer(frame.command_buffer, "blitCommandEncoder") orelse return false;
    msgSendCopyTextureToTexture(
        blit_encoder,
        "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
        source_texture,
        0,
        0,
        .{ .x = 0, .y = 0, .z = 0 },
        .{
            .width = @intCast(context.drawable_width),
            .height = @intCast(context.drawable_height),
            .depth = 1,
        },
        snap_m.texture,
        0,
        0,
        .{ .x = 0, .y = 0, .z = 0 },
    );
    msgSendVoid(blit_encoder, "endEncoding");
    return true;
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
