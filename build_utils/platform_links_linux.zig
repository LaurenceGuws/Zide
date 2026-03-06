const std = @import("std");

pub fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile) void {
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("pthread");
    exe.linkSystemLibrary("dl");
    exe.linkSystemLibrary("rt");
}

pub fn linkFfiPlatform(step: *std.Build.Step.Compile) void {
    step.linkSystemLibrary("m");
    step.linkSystemLibrary("pthread");
    step.linkSystemLibrary("dl");
    step.linkSystemLibrary("rt");
}

pub fn linkSdlTestGraphics(step: *std.Build.Step.Compile) void {
    step.linkSystemLibrary("GL");
}
