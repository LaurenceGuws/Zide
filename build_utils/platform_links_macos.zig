const std = @import("std");

pub fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile) void {
    exe.linkFramework("OpenGL");
    exe.linkFramework("Cocoa");
    exe.linkFramework("IOKit");
    exe.linkFramework("CoreVideo");
}

pub fn linkFfiPlatform(step: *std.Build.Step.Compile) void {
    step.linkFramework("Cocoa");
}

pub fn linkSdlTestGraphics(step: *std.Build.Step.Compile) void {
    step.linkFramework("OpenGL");
}
