const std = @import("std");
const zlua = @import("zlua");
const zlua_portable = @import("zlua_portable");

pub const Reader = struct {
    lua: *zlua.Lua,
    allocator: std.mem.Allocator,
    state: zlua_portable.api.State,
    table: zlua_portable.reader.Reader,

    pub fn init(lua: *zlua.Lua, allocator: std.mem.Allocator, idx: i32) Reader {
        const state = zlua_portable.api.State.fromRaw(@ptrCast(lua));
        return .{
            .lua = lua,
            .allocator = allocator,
            .state = state,
            .table = zlua_portable.reader.Reader.init(state, allocator, idx),
        };
    }

    pub fn child(self: Reader, field: []const u8) ?zlua_portable.reader.Reader {
        return self.table.child(field);
    }

    pub fn fieldString(self: Reader, field: []const u8) ?[]const u8 {
        return self.table.fieldString(field);
    }

    pub fn ownedStringField(self: Reader, field: []const u8) !?[]u8 {
        const value = self.fieldString(field) orelse return null;
        return try self.allocator.dupe(u8, value);
    }

    pub fn boolField(self: Reader, field: []const u8) ?bool {
        return self.table.boolField(field);
    }

    pub fn intField(self: Reader, field: []const u8) ?i64 {
        return self.table.intField(field);
    }

    pub fn numberField(self: Reader, field: []const u8) ?f64 {
        return self.table.numberField(field);
    }

    pub fn positiveF32Field(self: Reader, field: []const u8) ?f32 {
        const value = self.numberField(field) orelse return null;
        if (value <= 0) return null;
        return @floatCast(value);
    }

    pub fn stringOrStringListOwned(self: Reader, field: []const u8) !?[]u8 {
        self.state.getField(self.table.index, field);
        defer self.state.pop(1);

        if (self.state.readString(-1)) |value| {
            return try self.allocator.dupe(u8, value);
        }
        if (!self.state.isTable(-1)) return null;

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);

        const value_reader = zlua_portable.reader.Reader.init(self.state, self.allocator, -1);
        var it = value_reader.iter();
        defer it.finish();
        while (it.next()) {
            const value = it.valueString() orelse continue;
            if (out.items.len > 0) try out.append(self.allocator, ',');
            try out.appendSlice(self.allocator, value);
        }
        return try out.toOwnedSlice(self.allocator);
    }

    pub fn rawLen(self: Reader, idx: i32) usize {
        return self.state.rawLen(idx);
    }

    pub fn rawStringIndex(self: Reader, idx: i32, index_1_based: usize) ?[]const u8 {
        self.state.rawGetIndex(idx, index_1_based);
        defer self.state.pop(1);
        return self.state.readString(-1);
    }

    pub fn childRawIndex(self: Reader, idx: i32, index_1_based: usize) ?zlua_portable.reader.Reader {
        self.state.rawGetIndex(idx, index_1_based);
        if (!self.state.isTable(-1)) {
            self.state.pop(1);
            return null;
        }
        return zlua_portable.reader.Reader.init(self.state, self.allocator, -1);
    }
};
