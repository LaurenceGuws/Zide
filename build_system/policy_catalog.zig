const bootstrap_policy = @import("bootstrap_policy.zig");

pub const PolicyLine = struct {
    text: []const u8,
};

pub const PolicyOption = struct {
    flag: []const u8,
    description: []const u8,
};

pub const supported_options = [_]PolicyOption{
    .{ .flag = "-Dmode=ide|terminal|editor", .description = "select runtime app mode" },
    .{ .flag = "-Drenderer-backend=sdl_gl", .description = bootstrap_policy.supported_renderer_options[0].description },
    .{ .flag = "standard Zig target/optimize options", .description = "use standard Zig build target and optimize controls" },
};

pub const hard_constraints = [_]PolicyLine{
    .{ .text = "terminal mode must not resolve tree-sitter" },
    .{ .text = "non-terminal modes must resolve tree-sitter" },
    .{ .text = "renderer backend support is currently SDL GL only" },
    .{ .text = "build graph is intentionally split between runtime app planning and extended IDE/test planning" },
    .{ .text = "platform graphics/ffi assumptions are modeled per target OS" },
};

pub const operator_intent = [_]PolicyLine{
    .{ .text = "use report-build-surface for the step taxonomy" },
    .{ .text = "use report-build-profiles for the dependency profile matrix" },
    .{ .text = "use report-build-policy for the active option/constraint summary" },
};
