const std = @import("std");

pub fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile) void {
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("comdlg32");
    exe.linkSystemLibrary("dwrite");
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("winmm");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("shell32");
}

pub fn linkFfiPlatform(step: *std.Build.Step.Compile) void {
    step.linkSystemLibrary("user32");
    step.linkSystemLibrary("shell32");
}

pub fn linkSdlTestGraphics(step: *std.Build.Step.Compile) void {
    step.linkSystemLibrary("opengl32");
}
