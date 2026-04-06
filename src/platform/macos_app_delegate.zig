const std = @import("std");
const builtin = @import("builtin");
const native_host = @import("native_host.zig");
const macos_host = @import("macos_host.zig");

const objc = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {
    pub const SEL = *anyopaque;
    pub const BOOL = c_int;

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

    pub fn objc_allocateClassPair(superclass: *anyopaque, name: [*:0]const u8, extra_bytes: usize) ?*anyopaque {
        _ = superclass;
        _ = name;
        _ = extra_bytes;
        return null;
    }

    pub fn class_addMethod(cls: *anyopaque, name: SEL, imp: *const anyopaque, types: [*:0]const u8) BOOL {
        _ = cls;
        _ = name;
        _ = imp;
        _ = types;
        return 0;
    }

    pub fn objc_registerClassPair(cls: *anyopaque) void {
        _ = cls;
    }
};

const terminate_now: usize = 1;

var delegate_class_once = false;
var delegate_class: ?*anyopaque = null;
var active_app_host: ?*native_host.PlatformAppHost = null;
var previous_delegate: ?*anyopaque = null;

pub const Installation = struct {
    delegate: *anyopaque,
    previous_delegate: ?*anyopaque,
    installed: bool = false,
};

fn classPointer(class_name: [*:0]const u8) ?*anyopaque {
    return objc.objc_getClass(class_name);
}

fn selector(selector_name: [*:0]const u8) objc.SEL {
    return objc.sel_registerName(selector_name);
}

fn msgSendPointer(target: *anyopaque, selector_name: [*:0]const u8) ?*anyopaque {
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) ?*anyopaque = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name));
}

fn msgSendPointerArgVoid(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) void {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, selector(selector_name), value);
}

fn msgSendBool(target: *anyopaque, selector_name: [*:0]const u8) bool {
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) objc.BOOL = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name)) != 0;
}

fn msgSendBoolArgSel(target: *anyopaque, selector_name: [*:0]const u8, value: objc.SEL) bool {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, objc.SEL) callconv(.c) bool = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name), value);
}

fn msgSendUsizeArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) usize {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) usize = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name), value);
}

fn msgSendBoolArgPointerArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value_a: *anyopaque, value_b: *anyopaque) bool {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque, *anyopaque) callconv(.c) bool = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name), value_a, value_b);
}

fn msgSendVoidArgPointer(target: *anyopaque, selector_name: [*:0]const u8, value: *anyopaque) void {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, *anyopaque) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, selector(selector_name), value);
}

fn msgSendVoidArgNullablePointer(target: *anyopaque, selector_name: [*:0]const u8, value: ?*anyopaque) void {
    const fn_ptr: *const fn (*anyopaque, objc.SEL, ?*anyopaque) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(target, selector(selector_name), value);
}

fn msgSendStringPointer(target: *anyopaque, selector_name: [*:0]const u8) ?[*:0]const u8 {
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) ?[*:0]const u8 = @ptrCast(&objc.objc_msgSend);
    return fn_ptr(target, selector(selector_name));
}

fn retainObject(object: *anyopaque) *anyopaque {
    return msgSendPointer(object, "retain").?;
}

fn releaseObject(object: *anyopaque) void {
    const fn_ptr: *const fn (*anyopaque, objc.SEL) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
    fn_ptr(object, selector("release"));
}

fn sharedApplication() ?*anyopaque {
    const app_class = classPointer("NSApplication") orelse return null;
    return msgSendPointer(app_class, "sharedApplication");
}

fn forwardVoidNotification(selector_name: [*:0]const u8, notification: *anyopaque) void {
    const delegate = previous_delegate orelse return;
    const sel = selector(selector_name);
    if (!msgSendBoolArgSel(delegate, "respondsToSelector:", sel)) return;
    msgSendVoidArgPointer(delegate, selector_name, notification);
}

fn forwardTerminate(app: *anyopaque) usize {
    const delegate = previous_delegate orelse return terminate_now;
    const sel = selector("applicationShouldTerminate:");
    if (!msgSendBoolArgSel(delegate, "respondsToSelector:", sel)) return terminate_now;
    return msgSendUsizeArgPointer(delegate, "applicationShouldTerminate:", app);
}

fn forwardOpenFile(app: *anyopaque, filename: *anyopaque) bool {
    const delegate = previous_delegate orelse return true;
    const sel = selector("application:openFile:");
    if (!msgSendBoolArgSel(delegate, "respondsToSelector:", sel)) return true;
    return msgSendBoolArgPointerArgPointer(delegate, "application:openFile:", app, filename);
}

fn ensureDelegateClass() ?*anyopaque {
    if (builtin.target.os.tag != .macos) return null;
    if (delegate_class_once) return delegate_class;
    delegate_class_once = true;

    const existing = classPointer("ZideMacOSAppDelegateProxy");
    if (existing != null) {
        delegate_class = existing;
        return existing;
    }

    const ns_object = classPointer("NSObject") orelse return null;
    const cls = objc.objc_allocateClassPair(@ptrCast(ns_object), "ZideMacOSAppDelegateProxy", 0) orelse return null;

    _ = objc.class_addMethod(cls, selector("applicationDidBecomeActive:"), @ptrCast(&applicationDidBecomeActive), "v@:@");
    _ = objc.class_addMethod(cls, selector("applicationDidResignActive:"), @ptrCast(&applicationDidResignActive), "v@:@");
    _ = objc.class_addMethod(cls, selector("applicationWillTerminate:"), @ptrCast(&applicationWillTerminate), "v@:@");
    _ = objc.class_addMethod(cls, selector("applicationShouldTerminate:"), @ptrCast(&applicationShouldTerminate), "Q@:@");
    _ = objc.class_addMethod(cls, selector("application:openFile:"), @ptrCast(&applicationOpenFile), "B@:@@");
    objc.objc_registerClassPair(cls);
    delegate_class = @ptrCast(cls);
    return delegate_class;
}

fn applicationDidBecomeActive(self: *anyopaque, cmd: objc.SEL, notification: *anyopaque) callconv(.c) void {
    _ = self;
    _ = cmd;
    const handled = if (active_app_host) |app_host| macos_host.noteDidBecomeActive(app_host) else false;
    if (!handled) forwardVoidNotification("applicationDidBecomeActive:", notification);
}

fn applicationDidResignActive(self: *anyopaque, cmd: objc.SEL, notification: *anyopaque) callconv(.c) void {
    _ = self;
    _ = cmd;
    const handled = if (active_app_host) |app_host| macos_host.noteDidResignActive(app_host) else false;
    if (!handled) forwardVoidNotification("applicationDidResignActive:", notification);
}

fn applicationWillTerminate(self: *anyopaque, cmd: objc.SEL, notification: *anyopaque) callconv(.c) void {
    _ = self;
    _ = cmd;
    const handled = if (active_app_host) |app_host| macos_host.noteWillTerminate(app_host) else false;
    if (!handled) forwardVoidNotification("applicationWillTerminate:", notification);
}

fn applicationShouldTerminate(self: *anyopaque, cmd: objc.SEL, app: *anyopaque) callconv(.c) usize {
    _ = self;
    _ = cmd;
    if (active_app_host) |app_host| {
        return switch (macos_host.noteShouldTerminate(app_host)) {
            .now => terminate_now,
            .forward_to_previous_delegate => forwardTerminate(app),
        };
    }
    return forwardTerminate(app);
}

fn applicationOpenFile(self: *anyopaque, cmd: objc.SEL, app: *anyopaque, filename: *anyopaque) callconv(.c) objc.BOOL {
    _ = self;
    _ = cmd;
    var handled = false;
    if (active_app_host) |app_host| {
        if (msgSendStringPointer(filename, "UTF8String")) |raw| {
            handled = macos_host.noteOpenFile(app_host, std.mem.sliceTo(raw, 0));
        }
    }
    if (handled) return true;
    if (forwardOpenFile(app, filename)) return true;
    return handled;
}

pub fn install(app_host: *native_host.PlatformAppHost) ?Installation {
    if (builtin.target.os.tag != .macos) return null;
    const app = sharedApplication() orelse return null;
    const proxy_class = ensureDelegateClass() orelse return null;
    const delegate_alloc = msgSendPointer(proxy_class, "alloc") orelse return null;
    const delegate = msgSendPointer(delegate_alloc, "init") orelse return null;
    const previous = msgSendPointer(app, "delegate");
    const retained_previous = if (previous) |value| retainObject(value) else null;
    active_app_host = app_host;
    previous_delegate = retained_previous;
    msgSendPointerArgVoid(app, "setDelegate:", delegate);
    return .{
        .delegate = delegate,
        .previous_delegate = retained_previous,
        .installed = true,
    };
}

pub fn uninstall(installation: *Installation) void {
    if (!installation.installed) return;
    const app = sharedApplication() orelse return;
    msgSendVoidArgNullablePointer(app, "setDelegate:", installation.previous_delegate);
    active_app_host = null;
    previous_delegate = null;
    if (installation.previous_delegate) |delegate| releaseObject(delegate);
    releaseObject(installation.delegate);
    installation.installed = false;
}
