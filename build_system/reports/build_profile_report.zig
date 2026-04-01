const std = @import("std");
const target_profile = @import("target_profile");
const profile_catalog = @import("profile_catalog");

fn yn(value: bool) []const u8 {
    return if (value) "yes" else "no";
}

fn printProfile(
    name: []const u8,
    desc: []const u8,
    profile: profile_catalog.LinkProfile,
) !void {
    std.debug.print(
        "{s}: {s} | treesitter={s} text_stack={s} lua={s} fontconfig={s}\n",
        .{
            name,
            desc,
            yn(profile.include_treesitter),
            yn(profile.include_text_stack),
            yn(profile.include_lua),
            yn(profile.include_fontconfig),
        },
    );
}

pub fn main() !void {
    target_profile.assertPolicy();

    std.debug.print("build profile matrix\n", .{});
    for (profile_catalog.profiles) |spec| {
        try printProfile(spec.name, spec.description, spec.profile);
    }
}
