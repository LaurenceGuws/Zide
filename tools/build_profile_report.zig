const std = @import("std");
const profiles = @import("target_profile");

fn yn(value: bool) []const u8 {
    return if (value) "yes" else "no";
}

fn printProfile(
    name: []const u8,
    profile: profiles.LinkProfile,
) !void {
    std.debug.print(
        "{s}: treesitter={s} text_stack={s} lua={s} fontconfig={s}\n",
        .{
            name,
            yn(profile.include_treesitter),
            yn(profile.include_text_stack),
            yn(profile.include_lua),
            yn(profile.include_fontconfig),
        },
    );
}

pub fn main() !void {
    profiles.assertPolicy();

    std.debug.print("build profile matrix\n", .{});
    try printProfile("app_main", profiles.app_main);
    try printProfile("app_terminal", profiles.app_terminal);
    try printProfile("app_editor", profiles.app_editor);
    try printProfile("app_ide", profiles.app_ide);
    try printProfile("test_unit", profiles.test_unit);
    try printProfile("test_editor", profiles.test_editor);
    try printProfile("test_config", profiles.test_config);
    try printProfile("test_terminal_replay", profiles.test_terminal_replay);
    try printProfile("test_terminal_kitty_query", profiles.test_terminal_kitty_query);
    try printProfile("test_terminal_focus_reporting", profiles.test_terminal_focus_reporting);
    try printProfile("test_terminal_workspace", profiles.test_terminal_workspace);
}
