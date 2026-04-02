const std = @import("std");
const profile_catalog = @import("profile_catalog");

fn yn(value: bool) []const u8 {
    return if (value) "yes" else "no";
}

pub fn main() !void {
    std.debug.print("build dependency intent\n", .{});
    for (profile_catalog.profiles) |spec| {
        const profile = spec.profile;
        std.debug.print(
            "{s}: {s}\n  treesitter={s} text_stack={s} lua={s} fontconfig={s}\n",
            .{
                spec.name,
                spec.description,
                yn(profile.include_treesitter),
                yn(profile.include_text_stack),
                yn(profile.include_lua),
                yn(profile.include_fontconfig),
            },
        );
    }
}
