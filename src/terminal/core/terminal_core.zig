const std = @import("std");
const history_mod = @import("../model/history.zig");
const parser_mod = @import("../parser/parser.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const semantic_prompt_mod = @import("semantic_prompt.zig");
const palette_mod = @import("../protocol/palette.zig");

const Screen = screen_mod.Screen;
const Charset = parser_mod.Charset;
const CharsetTarget = parser_mod.CharsetTarget;
const SemanticPromptState = semantic_prompt_mod.SemanticPromptState;
const Hyperlink = snapshot_mod.Hyperlink;

const dynamic_color_count: usize = 10;

pub const ActiveScreen = enum {
    primary,
    alt,
};

pub const SavedCharsetState = struct {
    active: bool = false,
    g0: Charset = .ascii,
    g1: Charset = .ascii,
    gl: Charset = .ascii,
    target: CharsetTarget = .g0,
};

pub const InitOptions = struct {
    scrollback_rows: usize,
    cursor_style: ?types.CursorStyle = null,
};

pub const TerminalCore = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_buffer: std.ArrayList(u8),
    primary: Screen,
    alt: Screen,
    active: ActiveScreen,
    history: history_mod.TerminalHistory,
    parser: parser_mod.Parser,
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    kitty_osc5522_clipboard_text: std.ArrayList(u8),
    kitty_osc5522_clipboard_html: std.ArrayList(u8),
    kitty_osc5522_clipboard_uri_list: std.ArrayList(u8),
    kitty_osc5522_clipboard_png: std.ArrayList(u8),
    osc_hyperlink: std.ArrayList(u8),
    osc_hyperlink_active: bool,
    hyperlink_table: std.ArrayList(Hyperlink),
    current_hyperlink_id: u32,
    cwd: []const u8,
    cwd_buffer: std.ArrayList(u8),
    semantic_prompt: SemanticPromptState,
    semantic_prompt_aid: std.ArrayList(u8),
    semantic_cmdline: std.ArrayList(u8),
    semantic_cmdline_valid: bool,
    user_vars: std.StringHashMap([]u8),
    kitty_primary: kitty_mod.KittyState,
    kitty_alt: kitty_mod.KittyState,
    base_default_attrs: types.CellAttrs,
    palette_default: [256]types.Color,
    palette_current: [256]types.Color,
    dynamic_colors: [dynamic_color_count]?types.Color,
    sync_updates_active: bool,
    column_mode_132: bool,
    alt_last_active: bool,
    clear_generation: std.atomic.Value(u64),
    saved_charset: SavedCharsetState,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !TerminalCore {
        const default_attrs = types.defaultCell().attrs;
        var primary = try Screen.init(allocator, rows, cols, default_attrs);
        var alt = try Screen.init(allocator, rows, cols, default_attrs);
        if (options.cursor_style) |cursor_style| {
            primary.cursor_style = cursor_style;
            alt.cursor_style = cursor_style;
        }
        const history = try history_mod.TerminalHistory.init(allocator, options.scrollback_rows, cols);
        const palette_default = palette_mod.buildDefaultPalette();
        return .{
            .allocator = allocator,
            .title = "Terminal",
            .title_buffer = .empty,
            .primary = primary,
            .alt = alt,
            .active = .primary,
            .history = history,
            .parser = parser_mod.Parser.init(allocator),
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .kitty_osc5522_clipboard_text = .empty,
            .kitty_osc5522_clipboard_html = .empty,
            .kitty_osc5522_clipboard_uri_list = .empty,
            .kitty_osc5522_clipboard_png = .empty,
            .osc_hyperlink = .empty,
            .osc_hyperlink_active = false,
            .hyperlink_table = .empty,
            .current_hyperlink_id = 0,
            .cwd = "",
            .cwd_buffer = .empty,
            .semantic_prompt = .{},
            .semantic_prompt_aid = .empty,
            .semantic_cmdline = .empty,
            .semantic_cmdline_valid = false,
            .user_vars = std.StringHashMap([]u8).init(allocator),
            .kitty_primary = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .loading_image_id = null,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .kitty_alt = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .loading_image_id = null,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .base_default_attrs = default_attrs,
            .palette_default = palette_default,
            .palette_current = palette_default,
            .dynamic_colors = [_]?types.Color{null} ** dynamic_color_count,
            .sync_updates_active = false,
            .column_mode_132 = false,
            .alt_last_active = false,
            .clear_generation = std.atomic.Value(u64).init(0),
            .saved_charset = .{},
        };
    }

    pub fn deinit(self: *TerminalCore, owner: anytype) void {
        self.history.deinit();
        self.primary.deinit();
        self.alt.deinit();
        self.parser.deinit();
        self.osc_clipboard.deinit(self.allocator);
        self.kitty_osc5522_clipboard_text.deinit(self.allocator);
        self.kitty_osc5522_clipboard_html.deinit(self.allocator);
        self.kitty_osc5522_clipboard_uri_list.deinit(self.allocator);
        self.kitty_osc5522_clipboard_png.deinit(self.allocator);
        self.osc_hyperlink.deinit(self.allocator);
        self.cwd_buffer.deinit(self.allocator);
        self.semantic_prompt_aid.deinit(self.allocator);
        self.semantic_cmdline.deinit(self.allocator);
        var user_it = self.user_vars.iterator();
        while (user_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.user_vars.deinit();
        kitty_mod.deinitKittyState(owner, &self.kitty_primary);
        kitty_mod.deinitKittyState(owner, &self.kitty_alt);
        for (self.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.hyperlink_table.deinit(self.allocator);
        self.title_buffer.deinit(self.allocator);
    }

    pub fn activeScreen(self: *TerminalCore) *Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn activeScreenConst(self: *const TerminalCore) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn inactiveScreen(self: *TerminalCore) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    pub fn isAltActive(self: *const TerminalCore) bool {
        return self.active == .alt;
    }
};
