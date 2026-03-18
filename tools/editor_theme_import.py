#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
GENERATED_DIR = ROOT / "assets/themes/generated"
THEME_REGISTRY_PATH = ROOT / "assets/themes/init.lua"
SUPPORTED_THEMES = (
    "ayu",
    "catppuccin-mocha",
    "everforest-dark",
    "gruvbox-dark",
    "jellybeans-dark",
    "kanagawa-dragon",
    "material-oceanic",
    "monokai-classic",
    "monokai-pro",
    "monokai-ristretto",
    "monokai-soda",
    "modus-vivendi",
    "moonfly-dark",
    "nightfly-dark",
    "noctis-dark",
    "onedark-dark",
    "onedarkpro-onedark",
    "onedarkpro-onedark-vivid",
    "poimandres-main",
    "rose-pine-main",
    "sonokai-default",
    "tokyonight-night",
    "vim-enfocado-dark",
    "vaporwave",
)
THEME_SOURCES = {
    "ayu": [
        "~/.local/share/nvim/lazy/neovim-ayu/lua/ayu/colors.lua",
        "~/.local/share/nvim/lazy/neovim-ayu/lua/ayu/init.lua",
    ],
    "catppuccin-mocha": [
        "~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/mocha.lua",
        "~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/syntax.lua",
        "~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/treesitter.lua",
    ],
    "everforest-dark": [
        "~/.local/share/nvim/lazy/everforest/autoload/everforest.vim",
        "~/.local/share/nvim/lazy/everforest/colors/everforest.vim",
    ],
    "gruvbox-dark": [
        "~/.local/share/nvim/lazy/gruvbox.nvim/lua/gruvbox.lua",
    ],
    "jellybeans-dark": [
        "~/.local/share/nvim/lazy/jellybeans-nvim/lua/lush_theme/jellybeans-nvim.lua",
    ],
    "kanagawa-dragon": [
        "~/.local/share/nvim/lazy/kanagawa-dragon/lua/kanagawa/init.lua",
        "~/.local/share/nvim/lazy/kanagawa-dragon/lua/kanagawa/highlights/syntax.lua",
    ],
    "material-oceanic": [
        "~/.local/share/nvim/lazy/material.nvim/lua/material/colors/init.lua",
        "~/.local/share/nvim/lazy/material.nvim/lua/material/highlights/init.lua",
    ],
    "monokai-classic": [
        "~/.local/share/nvim/lazy/monokai.nvim/lua/monokai.lua",
    ],
    "monokai-pro": [
        "~/.local/share/nvim/lazy/monokai.nvim/lua/monokai.lua",
    ],
    "monokai-ristretto": [
        "~/.local/share/nvim/lazy/monokai.nvim/lua/monokai.lua",
    ],
    "monokai-soda": [
        "~/.local/share/nvim/lazy/monokai.nvim/lua/monokai.lua",
    ],
    "modus-vivendi": [
        "~/.local/share/nvim/lazy/modus-themes.nvim/extras/lua/modus_vivendi.lua",
    ],
    "moonfly-dark": [
        "~/.local/share/nvim/lazy/moonfly/autoload/moonfly.vim",
        "~/.local/share/nvim/lazy/moonfly/colors/moonfly.vim",
    ],
    "nightfly-dark": [
        "~/.local/share/nvim/lazy/nightfly/autoload/nightfly.vim",
        "~/.local/share/nvim/lazy/nightfly/colors/nightfly.vim",
    ],
    "noctis-dark": [
        "~/.local/share/nvim/lazy/noctis.nvim/lua/lush_theme/noctis.lua",
    ],
    "onedark-dark": [
        "~/.local/share/nvim/lazy/onedark.nvim/lua/onedark/palette.lua",
        "~/.local/share/nvim/lazy/onedark.nvim/lua/onedark/init.lua",
        "~/.local/share/nvim/lazy/onedark.nvim/lua/onedark/highlights.lua",
    ],
    "onedarkpro-onedark": [
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/themes/onedark.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/editor.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/syntax.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/plugins/treesitter.lua",
    ],
    "onedarkpro-onedark-vivid": [
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/themes/onedark_vivid.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/editor.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/syntax.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/plugins/treesitter.lua",
    ],
    "poimandres-main": [
        "~/.local/share/nvim/lazy/poimandres.nvim/lua/poimandres/palette.lua",
        "~/.local/share/nvim/lazy/poimandres.nvim/lua/poimandres/theme.lua",
        "~/.local/share/nvim/lazy/poimandres.nvim/lua/poimandres/init.lua",
    ],
    "rose-pine-main": [
        "~/.local/share/nvim/lazy/rose-pine/lua/rose-pine/palette.lua",
        "~/.local/share/nvim/lazy/rose-pine/lua/rose-pine/config.lua",
        "~/.local/share/nvim/lazy/rose-pine/lua/rose-pine.lua",
    ],
    "sonokai-default": [
        "~/.local/share/nvim/lazy/sonokai/autoload/sonokai.vim",
        "~/.local/share/nvim/lazy/sonokai/colors/sonokai.vim",
    ],
    "tokyonight-night": [
        "~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_night.lua",
    ],
    "vim-enfocado-dark": [
        "~/.local/share/nvim/lazy/vim-enfocado/autoload/enfocado.vim",
        "~/.local/share/nvim/lazy/vim-enfocado/colors/enfocado.vim",
    ],
    "vaporwave": [
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/themes/vaporwave.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/editor.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/syntax.lua",
        "~/.local/share/nvim/lazy/onedarkpro.nvim/lua/onedarkpro/highlights/plugins/treesitter.lua",
    ],
}

STYLE_KEYS = (
    "bold",
    "italic",
    "underline",
    "undercurl",
    "strikethrough",
    "reverse",
    "nocombine",
)
RESOLVED_PRUNE_MODES = ("none", "editor-surface")
AUDIT_EDITOR_GROUPS = (
    "Search",
    "IncSearch",
    "Visual",
    "LineNr",
    "CursorLine",
    "CursorLineNr",
    "MatchParen",
)
AUDIT_SYNTAX_GROUPS = (
    "Comment",
    "String",
    "Number",
    "Keyword",
    "Function",
    "Type",
    "Operator",
)
KNOWN_THEME_REPOS = {
    "Apprentice",
    "catppuccin",
    "doom-one.nvim",
    "everforest",
    "gruvbox.nvim",
    "jellybeans-nvim",
    "kanagawa-dragon",
    "material.nvim",
    "modus-themes.nvim",
    "monokai.nvim",
    "moonfly",
    "neovim-ayu",
    "nightfly",
    "noctis.nvim",
    "onedark.nvim",
    "onedarkpro.nvim",
    "papercolor-extra",
    "poimandres.nvim",
    "rose-pine",
    "sonokai",
    "tokyonight.nvim",
    "vim-enfocado",
}
REPO_TO_TARGETS = {
    "catppuccin": ("catppuccin-mocha",),
    "everforest": ("everforest-dark",),
    "gruvbox.nvim": ("gruvbox-dark",),
    "jellybeans-nvim": ("jellybeans-dark",),
    "kanagawa-dragon": ("kanagawa-dragon",),
    "material.nvim": ("material-oceanic",),
    "monokai.nvim": ("monokai-classic", "monokai-pro", "monokai-soda", "monokai-ristretto"),
    "modus-themes.nvim": ("modus-vivendi",),
    "moonfly": ("moonfly-dark",),
    "neovim-ayu": ("ayu",),
    "nightfly": ("nightfly-dark",),
    "noctis.nvim": ("noctis-dark",),
    "onedark.nvim": ("onedark-dark",),
    "onedarkpro.nvim": ("onedarkpro-onedark", "onedarkpro-onedark-vivid", "vaporwave"),
    "poimandres.nvim": ("poimandres-main",),
    "rose-pine": ("rose-pine-main",),
    "sonokai": ("sonokai-default",),
    "tokyonight.nvim": ("tokyonight-night",),
    "vim-enfocado": ("vim-enfocado-dark",),
}


@dataclass
class Entry:
    key: str
    fg: str | None = None
    bg: str | None = None
    sp: str | None = None
    link: str | None = None
    flags: dict[str, bool] = field(default_factory=dict)

    def style_only(self) -> bool:
        return bool(self.flags) or self.sp is not None or self.link is not None or self.fg is not None or self.bg is not None


@dataclass
class CoverageReport:
    groups: int
    captures: int
    links: int
    missing_editor: list[str]
    missing_syntax: list[str]
    present_styles: list[str]

    @property
    def editor_missing_count(self) -> int:
        return len(self.missing_editor)

    @property
    def syntax_missing_count(self) -> int:
        return len(self.missing_syntax)

    def ui_status(self) -> str:
        if not self.missing_editor:
            return "strong"
        if len(self.missing_editor) <= 2:
            return "partial"
        return "weak"

    def syntax_status(self) -> str:
        if not self.missing_syntax:
            return "strong"
        if len(self.missing_syntax) <= 2:
            return "partial"
        return "weak"


@dataclass
class ThemeFileProbe:
    path: Path
    shape: str
    status: str
    detail: str


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def brace_delta(text: str) -> int:
    delta = 0
    in_single = False
    in_double = False
    escaped = False
    for ch in text:
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if in_single:
            if ch == "'":
                in_single = False
            continue
        if in_double:
            if ch == '"':
                in_double = False
            continue
        if ch == "'":
            in_single = True
            continue
        if ch == '"':
            in_double = True
            continue
        if ch == "{":
            delta += 1
        elif ch == "}":
            delta -= 1
    return delta


ENTRY_RE = re.compile(
    r'^\s*(?:\[(?P<q>["\'])(?P<bracket_key>.+?)(?P=q)\]|(?P<plain_key>[A-Za-z0-9_@.]+))\s*=\s*(?P<rest>.+?)\s*,?\s*$'
)


def scan_entries(text: str) -> list[tuple[str, str]]:
    lines = text.splitlines()
    out: list[tuple[str, str]] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        match = ENTRY_RE.match(line)
        if not match:
            i += 1
            continue
        key = match.group("bracket_key") or match.group("plain_key")
        rest = match.group("rest").strip()
        if rest.startswith("{"):
            body_lines = [rest]
            depth = brace_delta(rest)
            while depth > 0 and i + 1 < len(lines):
                i += 1
                body_lines.append(lines[i])
                depth += brace_delta(lines[i])
            out.append((key, "\n".join(body_lines)))
        elif rest.startswith(("'", '"')):
            out.append((key, rest))
        i += 1
    return out


def parse_bool_flag(body: str, name: str) -> bool:
    return re.search(rf"\b{name}\s*=\s*true\b", body) is not None


def parse_color_literal(body: str, name: str) -> str | None:
    match = re.search(rf'\b{name}\s*=\s*["\'](#[0-9A-Fa-f]{{6,8}}|NONE)["\']', body)
    return match.group(1) if match else None


def parse_color_symbol(body: str, name: str) -> str | None:
    match = re.search(rf"\b{name}\s*=\s*colors\.([A-Za-z0-9_]+)", body)
    return match.group(1) if match else None


def parse_symbol_from_map(body: str, name: str, prefix: str, values: dict[str, str]) -> str | None:
    match = re.search(rf"\b{name}\s*=\s*{re.escape(prefix)}\.([A-Za-z0-9_]+)", body)
    if match and match.group(1) in values:
        return values[match.group(1)]
    return None


def parse_link(body: str) -> str | None:
    if body.startswith(("'", '"')):
        return body.strip().strip(",").strip("'\"")
    match = re.search(r'\blink\s*=\s*["\']([^"\']+)["\']', body)
    return match.group(1) if match else None


def parse_entry(key: str, body: str, color_map: dict[str, str] | None = None, inherited_flags: dict[str, bool] | None = None) -> Entry:
    entry = Entry(key=key)
    inherited_flags = inherited_flags or {}
    for flag_name, enabled in inherited_flags.items():
        if enabled:
            entry.flags[flag_name] = True
    for flag_name in STYLE_KEYS:
        if parse_bool_flag(body, flag_name):
            entry.flags[flag_name] = True
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        symbol = parse_color_symbol(body, color_name)
        if symbol is not None and color_map is not None and symbol in color_map:
            setattr(entry, color_name, color_map[symbol])
    return entry


def ayu_dark_colors(path: Path) -> dict[str, str]:
    text = read(path)
    start = text.find("      colors.accent = '#E6B450'")
    end = text.find("  else", start)
    block = text[start:end]
    out: dict[str, str] = {}
    for name, value in re.findall(r"colors\.([A-Za-z0-9_]+)\s*=\s*'(#?[0-9A-Fa-f]+)'", block):
        if value.startswith("#"):
            out[name] = value
    return out


def kanagawa_config_styles(path: Path) -> dict[str, dict[str, bool]]:
    text = read(path)
    out: dict[str, dict[str, bool]] = {}
    for name, body in re.findall(r"(\w+Style)\s*=\s*\{([^}]*)\}", text):
        flags = {flag: True for flag in STYLE_KEYS if re.search(rf"\b{flag}\s*=\s*true\b", body)}
        out[name] = flags
    return out


def parse_kanagawa_theme_maps(theme_root: Path) -> dict[str, str]:
    palette_text = read(theme_root / "lua/kanagawa/colors.lua")
    palette: dict[str, str] = {}
    for name, value in re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*\"(#[0-9A-Fa-f]{6,8}|none|NONE)\"", palette_text, re.MULTILINE):
        if value.lower() != "none":
            palette[name] = value

    themes_text = read(theme_root / "lua/kanagawa/themes.lua")
    dragon_table = extract_lua_table(themes_text, "dragon = function(palette)")
    out: dict[str, str] = {}
    for section in ("ui", "syn", "diag"):
        section_table = extract_lua_table(dragon_table, f"{section} =")
        for name, ref in re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*palette\.([A-Za-z0-9_]+)", section_table, re.MULTILINE):
            if ref in palette:
                out[f"{section}.{name}"] = palette[ref]
        for name, literal in re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*\"(#[0-9A-Fa-f]{6,8}|none|NONE)\"", section_table, re.MULTILINE):
            if literal.lower() != "none":
                out[f"{section}.{name}"] = literal
    return out


def parse_kanagawa_entry(key: str, body: str, theme_maps: dict[str, str], inherited_flags: dict[str, bool] | None = None) -> Entry:
    entry = Entry(key=key)
    inherited_flags = inherited_flags or {}
    for flag_name, enabled in inherited_flags.items():
        if enabled:
            entry.flags[flag_name] = True
    for flag_name in STYLE_KEYS:
        if parse_bool_flag(body, flag_name):
            entry.flags[flag_name] = True
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        match = re.search(rf"\b{color_name}\s*=\s*theme\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)", body)
        if match:
            resolved = theme_maps.get(f"{match.group(1)}.{match.group(2)}")
            if resolved is not None:
                setattr(entry, color_name, resolved)
    return entry


def extract_tokyonight(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    entries = scan_entries(read(theme_root / "extras/lua/tokyonight_night.lua"))
    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}
    interesting_prefixes = ("@keyword", "@markup", "@lsp.type.unresolvedReference", "@comment", "@markup.link.url")
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Bold",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineWarn",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineHint",
        "Italic",
        "Statement",
        "Tag",
        "Todo",
        "Underlined",
    }
    for key, body in entries:
        if key.startswith("@"):
            if key.startswith(interesting_prefixes):
                entry = parse_entry(key, body)
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    captures.append(entry)
        elif key in keep_groups:
            entry = parse_entry(key, body)
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    present = {entry.key for entry in groups}
    if "Number" not in present:
        links["Number"] = "Constant"
        groups.append(Entry(key="Number", link="Constant"))
    return groups, captures, links


def extract_ayu(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    color_map = ayu_dark_colors(theme_root / "lua/ayu/colors.lua")
    entries = scan_entries(read(theme_root / "lua/ayu/init.lua"))
    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Comment",
        "Underlined",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineWarn",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineHint",
        "MatchParen",
    }
    keep_captures = {"@tag.delimiter", "@lsp.type.namespace", "@lsp.type.type", "@lsp.type.class", "@lsp.type.enum", "@lsp.type.interface", "@lsp.type.struct", "@lsp.type.field", "@lsp.type.variable", "@lsp.type.property", "@lsp.type.enumMember", "@lsp.type.function", "@lsp.type.method", "@lsp.type.macro", "@lsp.type.decorator", "@lsp.mod.constant"}
    for key, body in entries:
        entry = parse_entry(key, body, color_map=color_map)
        if key.startswith("@"):
            if key in keep_captures:
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    captures.append(entry)
        elif key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    present = {entry.key for entry in groups}
    fallback_links = {
        "Number": "Constant",
        "Keyword": "Statement",
    }
    for key, target in fallback_links.items():
        if key not in present:
            links[key] = target
            groups.append(Entry(key=key, link=target))
    return groups, captures, links


def extract_kanagawa(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    syntax_entries = scan_entries(read(theme_root / "lua/kanagawa/highlights/syntax.lua"))
    editor_entries = scan_entries(read(theme_root / "lua/kanagawa/highlights/editor.lua"))
    style_map = kanagawa_config_styles(theme_root / "lua/kanagawa/init.lua")
    theme_maps = parse_kanagawa_theme_maps(theme_root)
    groups: list[Entry] = []
    links: dict[str, str] = {}
    style_binding = {
        "Comment": "commentStyle",
        "Function": "functionStyle",
        "Keyword": "keywordStyle",
        "Statement": "statementStyle",
        "Type": "typeStyle",
    }
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Bold",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineWarn",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineHint",
        "Error",
        "ErrorMsg",
        "Italic",
        "ModeMsg",
        "MoreMsg",
        "Todo",
        "Underlined",
        "WarningMsg",
    }
    for key, body in syntax_entries + editor_entries:
        inherited = style_map.get(style_binding.get(key, ""), {})
        entry = parse_kanagawa_entry(key, body, theme_maps, inherited_flags=inherited)
        if key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    present = {entry.key for entry in groups}
    fallback_links = {
        "Comment": "Italic",
        "Keyword": "Statement",
        "Function": "Identifier",
        "Type": "Keyword",
    }
    for key, target in fallback_links.items():
        if key not in present:
            links[key] = target
            groups.append(Entry(key=key, link=target))
    return groups, [], links


def catppuccin_palette(path: Path) -> dict[str, str]:
    text = read(path)
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"', text, re.MULTILINE):
        out[name] = value
    return out


def rose_pine_palette(path: Path) -> dict[str, str]:
    text = read(path)
    match = re.search(r"main\s*=\s*\{(.*?)\n\t\},", text, re.DOTALL)
    if not match:
        raise SystemExit("failed to locate rose-pine main palette")
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8}|NONE)"', match.group(1), re.MULTILINE):
        if value != "NONE":
            out[name] = value
    return out


def rose_pine_group_colors(config_path: Path, palette: dict[str, str]) -> dict[str, str]:
    text = read(config_path)
    match = re.search(r"groups\s*=\s*\{(.*?)\n\t\},", text, re.DOTALL)
    if not match:
        raise SystemExit("failed to locate rose-pine group palette")
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"([A-Za-z0-9_]+)"', match.group(1), re.MULTILINE):
        if value in palette:
            out[name] = palette[value]
    return out


def onedark_palette(path: Path, variant: str) -> dict[str, str]:
    text = read(path)
    match = re.search(rf"{re.escape(variant)}\s*=\s*\{{(.*?)\n\t\}},", text, re.DOTALL)
    if not match:
        raise SystemExit(f"failed to locate onedark palette for {variant}")
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"', match.group(1), re.MULTILINE):
        out[name] = value
    return out


def onedark_default_styles(path: Path) -> dict[str, str]:
    text = read(path)
    match = re.search(r"code_style\s*=\s*\{(.*?)\n\s*\},", text, re.DOTALL)
    if not match:
        raise SystemExit("failed to locate onedark code_style defaults")
    out: dict[str, str] = {}
    for name, value in re.findall(r"([A-Za-z0-9_]+)\s*=\s*'([^']+)'", match.group(1)):
        out[name] = value
    return out


def onedarkpro_palette(path: Path) -> dict[str, str]:
    text = read(path)
    match = re.search(r"default_colors\s*=\s*\{(.*?)\n\}", text, re.DOTALL)
    if not match:
        raise SystemExit("failed to locate onedarkpro default palette")
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8}|NONE)"', match.group(1), re.MULTILINE):
        if value != "NONE":
            out[name] = value
    return out


def onedarkpro_generated(path: Path) -> dict[str, str]:
    text = read(path)
    match = re.search(r"local function generate\(colors\)(.*?)end", text, re.DOTALL)
    if not match:
        raise SystemExit("failed to locate onedarkpro generated colors")
    out: dict[str, str] = {}
    for name, value in re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*colors\.[A-Za-z0-9_]+\s+or\s+"(#[0-9A-Fa-f]{6,8})"', match.group(1), re.MULTILINE):
        out[name] = value
    return out


def parse_rose_pine_entry(key: str, body: str, palette: dict[str, str], group_colors: dict[str, str]) -> Entry:
    entry = Entry(key=key)
    if "italic = styles.italic" in body:
        entry.flags["italic"] = True
    if "bold = styles.bold" in body:
        entry.flags["bold"] = True
    for flag_name in STYLE_KEYS:
        if parse_bool_flag(body, flag_name):
            entry.flags[flag_name] = True
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        palette_value = parse_symbol_from_map(body, color_name, "palette", palette)
        if palette_value is not None:
            setattr(entry, color_name, palette_value)
            continue
        group_value = parse_symbol_from_map(body, color_name, "groups", group_colors)
        if group_value is not None:
            setattr(entry, color_name, group_value)
    return entry


def apply_onedark_fmt(entry: Entry, fmt: str | None) -> None:
    if not fmt:
        return
    for part in fmt.split(","):
        flag = part.strip()
        if not flag or flag == "NONE" or flag == "none":
            continue
        if flag in STYLE_KEYS:
            entry.flags[flag] = True


def parse_onedark_entry(key: str, body: str, palette: dict[str, str], style_defaults: dict[str, str]) -> Entry:
    entry = Entry(key=key)

    if body.startswith("colors."):
        alias = body.split(".", 1)[1].strip().strip(",")
        return parse_onedark_entry(key, "{ " + alias + " }", palette, style_defaults)

    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        value = parse_symbol_from_map(body, color_name, "c", palette)
        if value is not None:
            setattr(entry, color_name, value)

    fmt_match = re.search(r'fmt\s*=\s*["\']([^"\']+)["\']', body)
    if fmt_match:
        apply_onedark_fmt(entry, fmt_match.group(1))

    style_match = re.search(r"fmt\s*=\s*cfg\.code_style\.([A-Za-z0-9_]+)", body)
    if style_match:
        apply_onedark_fmt(entry, style_defaults.get(style_match.group(1)))

    conditional_fmt_match = re.search(r'fmt\s*=\s*cfg\.diagnostics\.undercurl\s+and\s+["\']([^"\']+)["\']\s+or\s+["\']([^"\']+)["\']', body)
    if conditional_fmt_match:
        apply_onedark_fmt(entry, conditional_fmt_match.group(1))

    link = parse_link(body)
    if link is not None:
        entry.link = link

    return entry


def parse_onedarkpro_entry(key: str, body: str, palette: dict[str, str], generated: dict[str, str]) -> Entry:
    entry = Entry(key=key)

    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        value = parse_symbol_from_map(body, color_name, "theme.palette", palette)
        if value is not None:
            setattr(entry, color_name, value)
            continue
        value = parse_symbol_from_map(body, color_name, "theme.generated", generated)
        if value is not None:
            setattr(entry, color_name, value)
            continue

        match = re.search(rf"\b{color_name}\s*=\s*.*?theme\.palette\.([A-Za-z0-9_]+)", body)
        if match and match.group(1) in palette:
            setattr(entry, color_name, palette[match.group(1)])
            continue

        match = re.search(rf"\b{color_name}\s*=\s*.*?theme\.generated\.([A-Za-z0-9_]+)", body)
        if match and match.group(1) in generated:
            setattr(entry, color_name, generated[match.group(1)])
            continue

        if color_name == "bg" and "theme.generated.selection" in body and "highlight" in palette:
            entry.bg = palette["highlight"]

    link = parse_link(body)
    if link is not None:
        entry.link = link

    for flag_name in ("bold", "italic", "underline", "strikethrough"):
        if re.search(rf"\b{flag_name}\s*=\s*true\b", body):
            entry.flags[flag_name] = True

    return entry


def parse_style_list(body: str) -> dict[str, bool]:
    flags: dict[str, bool] = {}
    match = re.search(r"style\s*=\s*\{([^}]*)\}", body, re.DOTALL)
    if not match:
        return flags
    for flag_name in STYLE_KEYS:
        if re.search(rf'["\']{flag_name}["\']', match.group(1)):
            flags[flag_name] = True
    return flags


def extract_lua_table(text: str, marker: str) -> str:
    start = text.find(marker)
    if start == -1:
        raise SystemExit(f"failed to locate lua table marker: {marker}")
    brace_start = text.find("{", start)
    if brace_start == -1:
        raise SystemExit(f"failed to locate opening brace for marker: {marker}")
    depth = 0
    i = brace_start
    in_single = False
    in_double = False
    escaped = False
    while i < len(text):
        ch = text[i]
        if escaped:
            escaped = False
        elif ch == "\\":
            escaped = True
        elif in_single:
            if ch == "'":
                in_single = False
        elif in_double:
            if ch == '"':
                in_double = False
        elif ch == "'":
            in_single = True
        elif ch == '"':
            in_double = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start:i + 1]
        i += 1
    raise SystemExit(f"unterminated lua table for marker: {marker}")


def parse_simple_lua_palette(text: str, marker: str) -> dict[str, str]:
    table = extract_lua_table(text, marker)
    out: dict[str, str] = {}
    for name, value in re.findall(r'([A-Za-z0-9_]+)\s*=\s*[\'"](#?[0-9A-Fa-f]{6,8})[\'"]', table):
        out[name] = value
    return out


def parse_vim_palette_block(text: str, function_name: str) -> dict[str, str]:
    start = text.find(function_name)
    if start == -1:
        raise SystemExit(f"failed to locate vim palette function: {function_name}")
    matches = re.findall(r"let palette\d* = \{(.*?)^\s*\\ \}", text[start:], re.DOTALL | re.MULTILINE)
    if not matches:
        raise SystemExit(f"failed to locate vim palette block for {function_name}")
    out: dict[str, str] = {}
    for block in matches[:2]:
        for name, value in re.findall(r"'([A-Za-z0-9_]+)'\s*:\s*\['(#[0-9A-Fa-f]{6,8}|NONE)'", block):
            if value != "NONE":
                out[name] = value
    return out


def parse_vim_palette_ref(arg: str, palette: dict[str, str]) -> str | None:
    arg = arg.strip()
    match = re.match(r"s:palette\.([A-Za-z0-9_]+)", arg)
    if match:
        return palette.get(match.group(1))
    if arg in {"s:palette.none", "s:none", "''", '""'}:
        return None
    return None


def apply_style_csv(entry: Entry, styles: str | None) -> None:
    if not styles:
        return
    for flag in styles.split(","):
        name = flag.strip()
        if not name or name == "NONE" or name == "none":
            continue
        if name in STYLE_KEYS:
            entry.flags[name] = True


def extract_vimscript_theme(autoload_path: Path, colors_path: Path, theme_fn: str, palette_fn: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    palette = parse_vim_palette_block(read(autoload_path), palette_fn)
    text = read(colors_path)
    groups_map: dict[str, Entry] = {}
    links: dict[str, str] = {}

    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Bold",
        "Comment",
        "Conditional",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineOk",
        "DiagnosticUnderlineWarn",
        "ErrorMsg",
        "Function",
        "Italic",
        "Keyword",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "String",
        "Todo",
        "Type",
        "Underlined",
        "WarningMsg",
    }

    pattern = re.compile(
        rf"call\s+{re.escape(theme_fn)}#highlight\('([^']+)'\s*,\s*([^,]+)\s*,\s*([^,]+)(?:\s*,\s*'([^']*)')?(?:\s*,\s*([^)]+))?\)"
    )
    for group, fg_arg, bg_arg, style_arg, sp_arg in pattern.findall(text):
        if group not in keep_groups:
            continue
        entry = Entry(key=group)
        entry.fg = parse_vim_palette_ref(fg_arg, palette)
        entry.bg = parse_vim_palette_ref(bg_arg, palette)
        entry.sp = parse_vim_palette_ref(sp_arg, palette) if sp_arg else None
        apply_style_csv(entry, style_arg)
        if entry.style_only():
            groups_map[group] = entry

    for source, target in re.findall(r"highlight!\s+link\s+([A-Za-z0-9_@.]+)\s+([A-Za-z0-9_@.]+)", text):
        if source in keep_groups:
            links[source] = target
    fallback_links = {
        "Number": "Constant",
        "Keyword": "Statement",
        "IncSearch": "Search",
        "Visual": "VisualNOS",
        "Function": "Identifier",
        "String": "Constant",
        "Type": "Keyword",
        "Operator": "Keyword",
    }
    for group, target in fallback_links.items():
        if group in keep_groups and group not in groups_map:
            links[group] = target
            groups_map[group] = Entry(key=group, link=target)

    return list(groups_map.values()), [], links


def parse_monokai_style(entry: Entry, body: str) -> None:
    style_match = re.search(r"style\s*=\s*'([^']+)'", body)
    if style_match:
        apply_style_csv(entry, style_match.group(1))


def parse_monokai_entry(key: str, body: str, palette: dict[str, str], aliases: dict[str, Entry]) -> Entry:
    entry = Entry(key=key)
    body = body.strip()
    if body in aliases:
        alias = aliases[body]
        entry.fg = alias.fg
        entry.bg = alias.bg
        entry.sp = alias.sp
        entry.link = alias.link
        entry.flags = dict(alias.flags)
        return entry
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        value = parse_symbol_from_map(body, color_name, "palette", palette)
        if value is not None:
            setattr(entry, color_name, value)
    parse_monokai_style(entry, body)
    return entry


def extract_monokai(theme_root: Path, variant: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    text = read(theme_root / "lua/monokai.lua")
    palette = parse_simple_lua_palette(text, f"M.{variant} =")
    syntax_table = extract_lua_table(text, "M.load_syntax = function(palette)")
    plugin_table = extract_lua_table(text, "M.load_plugin_syntax = function(palette)")

    alias_defs: dict[str, Entry] = {}
    for name, body in re.findall(r"local\s+([A-Za-z0-9_]+)\s*=\s*(\{.*?\})", text, re.DOTALL):
        if name in {"math_group", "strike_group", "todo_group", "uri_group"}:
            alias_defs[name] = parse_monokai_entry(name, body, palette, {})

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "ErrorMsg",
        "Function",
        "Keyword",
        "MatchParen",
        "ModeMsg",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    keep_captures = {
        "@comment",
        "@constant",
        "@function",
        "@function.builtin",
        "@function.call",
        "@function.macro",
        "@keyword",
        "@keyword.function",
        "@keyword.operator",
        "@keyword.return",
        "@markup.italic",
        "@markup.link.url",
        "@markup.strikethrough",
        "@markup.strong",
        "@markup.underline",
        "@number",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.escape",
        "@string.regex",
        "@string.special",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@type.qualifier",
        "@variable",
        "@variable.builtin",
    }

    for key, body in scan_entries(syntax_table[1:-1]):
        entry = parse_monokai_entry(key, body, palette, alias_defs)
        if key in keep_groups and entry.style_only():
            groups.append(entry)

    for key, body in scan_entries(plugin_table[1:-1]):
        entry = parse_monokai_entry(key, body, palette, alias_defs)
        if key in keep_captures and entry.style_only():
            captures.append(entry)

    return groups, captures, links


def parse_gruvbox_entry(key: str, body: str, colors: dict[str, str]) -> Entry:
    entry = Entry(key=key)
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        value = parse_symbol_from_map(body, color_name, "colors", colors)
        if value is not None:
            setattr(entry, color_name, value)
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for flag_name in STYLE_KEYS:
        if re.search(rf"\b{flag_name}\s*=\s*(?:config\.[A-Za-z0-9_]+|true)\b", body):
            entry.flags[flag_name] = True
    return entry


def extract_gruvbox(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    text = read(theme_root / "lua/gruvbox.lua")
    palette = parse_simple_lua_palette(text, "Gruvbox.palette =")
    colors = {
        "bg0": palette["dark0"],
        "bg1": palette["dark1"],
        "bg2": palette["dark2"],
        "bg3": palette["dark3"],
        "bg4": palette["dark4"],
        "fg0": palette["light0"],
        "fg1": palette["light1"],
        "fg2": palette["light2"],
        "fg3": palette["light3"],
        "fg4": palette["light4"],
        "red": palette["bright_red"],
        "green": palette["bright_green"],
        "yellow": palette["bright_yellow"],
        "blue": palette["bright_blue"],
        "purple": palette["bright_purple"],
        "aqua": palette["bright_aqua"],
        "orange": palette["bright_orange"],
        "neutral_red": palette["neutral_red"],
        "neutral_green": palette["neutral_green"],
        "neutral_yellow": palette["neutral_yellow"],
        "neutral_blue": palette["neutral_blue"],
        "neutral_purple": palette["neutral_purple"],
        "neutral_aqua": palette["neutral_aqua"],
        "dark_red": palette["dark_red"],
        "dark_green": palette["dark_green"],
        "dark_aqua": palette["dark_aqua"],
        "gray": palette["gray"],
    }
    groups_table = extract_lua_table(text, "local groups =")
    groups: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "ErrorMsg",
        "Function",
        "Keyword",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineWarn",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineHint",
    }
    for key, body in scan_entries(groups_table[1:-1]):
        entry = parse_gruvbox_entry(key, body, colors)
        if key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    return groups, [], links


def parse_style_string_value(value: str, entry: Entry) -> None:
    if value == "italic":
        entry.flags["italic"] = True
    elif value == "bold":
        entry.flags["bold"] = True
    elif value == "underline":
        entry.flags["underline"] = True
    elif value == "undercurl":
        entry.flags["undercurl"] = True
    elif value == "reverse":
        entry.flags["reverse"] = True


def parse_material_colors(theme_root: Path) -> dict[str, str]:
    text = read(theme_root / "lua/material/colors/init.lua")
    out: dict[str, str] = {}
    for section, key, value in re.findall(r"colors\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*=\s*\"(#[0-9A-Fa-f]{6,8}|NONE)\"", text):
        if value != "NONE":
            out[f"{section}.{key}"] = value
    changed = True
    while changed:
        changed = False
        for dst_section, dst_key, src_section, src_key in re.findall(
            r"colors\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*=\s*colors\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)",
            text,
        ):
            dst = f"{dst_section}.{dst_key}"
            src = f"{src_section}.{src_key}"
            if dst not in out and src in out:
                out[dst] = out[src]
                changed = True
    return out


def parse_material_entry(key: str, body: str, colors: dict[str, str]) -> Entry:
    entry = Entry(key=key)
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        match = re.search(rf"\b{color_name}\s*=\s*([mesblg])\.([A-Za-z0-9_]+)", body)
        if match:
            section_map = {"m": "main", "e": "editor", "s": "syntax", "b": "backgrounds", "l": "lsp", "g": "git"}
            resolved = colors.get(f"{section_map[match.group(1)]}.{match.group(2)}")
            if resolved is not None:
                setattr(entry, color_name, resolved)
    style_match = re.search(r"style\s*=\s*'([^']+)'", body)
    if style_match:
        apply_style_csv(entry, style_match.group(1))
    for flag_name in STYLE_KEYS:
        if parse_bool_flag(body, flag_name):
            entry.flags[flag_name] = True
    return entry


def extract_material(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    colors = parse_material_colors(theme_root)
    text = read(theme_root / "lua/material/highlights/init.lua")
    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    syntax_table = extract_lua_table(text, "local syntax_hls =")
    editor_main_table = extract_lua_table(text, "local editor_hls =")
    editor_async_table = extract_lua_table(text[text.find("M.async_highlights.editor"):], "local editor_hls =")
    lsp_async_table = extract_lua_table(text[text.find("M.async_highlights.load_lsp"):], "local lsp_hls =")
    treesitter_table = extract_lua_table(text, "local treesitter_hls =")

    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineWarn",
        "Error",
        "ErrorMsg",
        "Function",
        "Include",
        "Keyword",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    keep_captures = {
        "@boolean",
        "@comment",
        "@comment.error",
        "@comment.hint",
        "@comment.note",
        "@comment.todo",
        "@comment.warning",
        "@constant",
        "@constant.builtin",
        "@function",
        "@function.builtin",
        "@function.call",
        "@keyword",
        "@keyword.conditional",
        "@keyword.directive",
        "@keyword.function",
        "@keyword.import",
        "@keyword.operator",
        "@keyword.repeat",
        "@keyword.return",
        "@markup.emphasis",
        "@markup.heading",
        "@markup.link",
        "@markup.link.url",
        "@markup.list.checked",
        "@markup.list.unchecked",
        "@markup.raw",
        "@markup.strong",
        "@markup.underline",
        "@module",
        "@number",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.escape",
        "@string.regexp",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@type.definition",
        "@type.qualifier",
        "@variable",
        "@variable.builtin",
        "@variable.member",
        "@variable.parameter",
        "@lsp.type.unresolvedReference",
    }

    for table_text in (syntax_table[1:-1], editor_main_table[1:-1], editor_async_table[1:-1], lsp_async_table[1:-1]):
        for key, body in scan_entries(table_text):
            entry = parse_material_entry(key, body, colors)
            if key in keep_groups:
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    groups.append(entry)

    for key, body in scan_entries(treesitter_table[1:-1]):
        entry = parse_material_entry(key, body, colors)
        if key in keep_captures:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                captures.append(entry)

    return groups, captures, links


def parse_poimandres_maps(theme_root: Path) -> tuple[dict[str, str], dict[str, str]]:
    palette = parse_simple_lua_palette(read(theme_root / "lua/poimandres/palette.lua"), "main =")
    init_text = read(theme_root / "lua/poimandres/init.lua")
    groups_map: dict[str, str] = {}
    for name, value in re.findall(r"([A-Za-z0-9_]+)\s*=\s*'([A-Za-z0-9_]+)'", extract_lua_table(init_text, "groups =")):
        groups_map[name] = value
    return palette, groups_map


def parse_poimandres_entry(key: str, body: str, palette: dict[str, str], groups_map: dict[str, str]) -> Entry:
    entry = Entry(key=key)
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        match = re.search(rf"\b{color_name}\s*=\s*p\.([A-Za-z0-9_]+)", body)
        if match and match.group(1) in palette:
            setattr(entry, color_name, palette[match.group(1)])
            continue
        match = re.search(rf"\b{color_name}\s*=\s*groups\.([A-Za-z0-9_]+)", body)
        if match:
            mapped = groups_map.get(match.group(1))
            if mapped and mapped in palette:
                setattr(entry, color_name, palette[mapped])
    style_match = re.search(r"style\s*=\s*'([^']+)'", body)
    if style_match:
        apply_style_csv(entry, style_match.group(1))
    style_ref = re.search(r"style\s*=\s*styles\.([A-Za-z0-9_]+)", body)
    if style_ref:
        if style_ref.group(1) == "italic":
            entry.flags["italic"] = True
    return entry


def extract_poimandres(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    palette, groups_map = parse_poimandres_maps(theme_root)
    table = extract_lua_table(read(theme_root / "lua/poimandres/theme.lua"), "theme = {\n    ColorColumn")
    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Bold",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineWarn",
        "Error",
        "ErrorMsg",
        "Function",
        "Italic",
        "Keyword",
        "MatchParen",
        "ModeMsg",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    keep_captures = {
        "@boolean",
        "@comment",
        "@constant.builtin",
        "@constructor",
        "@function",
        "@function.builtin",
        "@function.call",
        "@keyword",
        "@keyword.function",
        "@keyword.operator",
        "@keyword.return",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.escape",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@variable",
        "@variable.builtin",
        "@markup.link.url",
    }
    for key, body in scan_entries(table[1:-1]):
        entry = parse_poimandres_entry(key, body, palette, groups_map)
        if key.startswith("@"):
            if key in keep_captures:
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    captures.append(entry)
        elif key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    return groups, captures, links


def extract_nightfly(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    return extract_fly_theme(theme_root, "nightfly")


def extract_fly_theme(theme_root: Path, theme_name: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    text = read(theme_root / f"autoload/{theme_name}.vim")
    colors = {name: value for name, value in re.findall(r"let s:([A-Za-z0-9_]+)\s*=\s*'(#?[0-9A-Fa-f]{6,8})'", text)}
    raw_entries: dict[str, Entry] = {}
    raw_links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "ErrorMsg",
        "Function",
        "Keyword",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    for line in text.splitlines():
        if "exec 'highlight " not in line:
            continue
        match = re.search(r"exec 'highlight ([A-Za-z0-9_]+)\b", line)
        if not match:
            continue
        group = match.group(1)
        entry = Entry(key=group)
        fg = re.search(r"guifg=(?:' \.\s*)?s:([A-Za-z0-9_]+)", line)
        if fg and fg.group(1) in colors:
            entry.fg = colors[fg.group(1)]
        bg = re.search(r"guibg=(?:' \.\s*)?s:([A-Za-z0-9_]+)", line)
        if bg and bg.group(1) in colors:
            entry.bg = colors[bg.group(1)]
        styles = re.search(r"gui=([A-Za-z,]+)", line)
        if styles:
            apply_style_csv(entry, styles.group(1))
        if entry.style_only():
            raw_entries[group] = entry
    for source, target in re.findall(r"highlight!\s+link\s+([A-Za-z0-9_@.]+)\s+([A-Za-z0-9_@.]+)", text):
        raw_links[source] = target

    def resolve_group(name: str, seen: set[str] | None = None) -> Entry | None:
        seen = seen or set()
        if name in seen:
            return None
        seen.add(name)
        if name in raw_entries:
            return raw_entries[name]
        target = raw_links.get(name)
        if target is None:
            return None
        resolved = resolve_group(target, seen)
        if resolved is None:
            return None
        entry = Entry(key=name, fg=resolved.fg, bg=resolved.bg, sp=resolved.sp, link=target, flags=dict(resolved.flags))
        return entry

    groups: list[Entry] = []
    links: dict[str, str] = {}
    for group in keep_groups:
        entry = resolve_group(group)
        if entry is None or not entry.style_only():
            continue
        if group in raw_links:
            links[group] = raw_links[group]
        groups.append(entry)
    present = {entry.key for entry in groups}
    fallback_links = {
        "Number": "Constant",
        "Keyword": "Statement",
    }
    for group, target in fallback_links.items():
        if group in keep_groups and group not in present:
            entry = resolve_group(target)
            if entry is None or not entry.style_only():
                continue
            links[group] = target
            groups.append(Entry(key=group, fg=entry.fg, bg=entry.bg, sp=entry.sp, link=target, flags=dict(entry.flags)))
    return groups, [], links


def parse_simple_table_block(text: str, marker: str) -> str:
    return extract_lua_table(text, marker)


def parse_simple_table_entries(table_text: str) -> list[tuple[str, str]]:
    return scan_entries(table_text[1:-1])


def parse_modus_entry(key: str, body: str, colors: dict[str, str]) -> Entry:
    entry = Entry(key=key)
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        match = re.search(rf"\b{color_name}\s*=\s*colors\.([A-Za-z0-9_]+)", body)
        if match and match.group(1) in colors:
            setattr(entry, color_name, colors[match.group(1)])
    style_match = re.search(r'gui\s*=\s*"([^"]+)"', body)
    if style_match:
        apply_style_csv(entry, style_match.group(1))
    return entry


def extract_modus(theme_root: Path, variant: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    text = read(theme_root / f"extras/lua/{variant}.lua")
    colors = parse_simple_lua_palette(text, "local colors =")
    table = parse_simple_table_block(text, "local highlights =")
    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Bold",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "Error",
        "ErrorMsg",
        "Function",
        "Identifier",
        "Keyword",
        "LineNr",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Title",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    keep_captures = {
        "@attribute",
        "@boolean",
        "@comment",
        "@comment.error",
        "@comment.note",
        "@comment.todo",
        "@comment.warning",
        "@constant",
        "@constant.builtin",
        "@constructor",
        "@function",
        "@function.builtin",
        "@function.call",
        "@function.method",
        "@keyword",
        "@keyword.conditional",
        "@keyword.directive",
        "@keyword.import",
        "@keyword.operator",
        "@keyword.repeat",
        "@keyword.return",
        "@label",
        "@number",
        "@operator",
        "@property",
        "@string",
        "@string.escape",
        "@type",
        "@type.builtin",
        "@variable",
        "@variable.builtin",
    }
    for key, body in parse_simple_table_entries(table):
        entry = parse_modus_entry(key, body, colors)
        if key.startswith("@"):
            if key in keep_captures:
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    captures.append(entry)
        elif key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    return groups, captures, links


def parse_lush_props(body: str, color_vars: dict[str, str]) -> Entry:
    entry = Entry(key="")
    literal_link = re.fullmatch(r"\s*([A-Za-z0-9_@.]+)\s*", body)
    if literal_link:
        entry.link = literal_link.group(1)
        return entry
    fg_match = re.search(r'fg\s*=\s*(?:"(#[0-9A-Fa-f]{6,8}|[A-Za-z]+)"|([A-Za-z0-9_]+))', body)
    if fg_match:
        if fg_match.group(1) and fg_match.group(1).startswith("#"):
            entry.fg = fg_match.group(1)
        elif fg_match.group(2) in color_vars:
            entry.fg = color_vars[fg_match.group(2)]
    bg_match = re.search(r'bg\s*=\s*(?:"(#[0-9A-Fa-f]{6,8}|[A-Za-z]+)"|([A-Za-z0-9_]+))', body)
    if bg_match:
        if bg_match.group(1) and bg_match.group(1).startswith("#"):
            entry.bg = bg_match.group(1)
        elif bg_match.group(2) in color_vars:
            entry.bg = color_vars[bg_match.group(2)]
    sp_match = re.search(r'sp\s*=\s*(?:"(#[0-9A-Fa-f]{6,8})"|([A-Za-z0-9_]+))', body)
    if sp_match:
        if sp_match.group(1):
            entry.sp = sp_match.group(1)
        elif sp_match.group(2) in color_vars:
            entry.sp = color_vars[sp_match.group(2)]
    gui_match = re.search(r'gui\s*=\s*"([^"]+)"', body)
    if gui_match:
        apply_style_csv(entry, gui_match.group(1))
    return entry


def extract_lush_literal_theme(theme_root: Path, rel_path: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    text = read(theme_root / rel_path)
    color_vars = {name: value for name, value in re.findall(r'local\s+([A-Za-z0-9_]+)\s*=\s*hsl\("(#[0-9A-Fa-f]{6,8})"\)', text)}
    groups: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Bold",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "Error",
        "ErrorMsg",
        "Function",
        "Identifier",
        "Include",
        "Keyword",
        "LineNr",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Title",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
        "WarningMsg",
    }
    patterns = (
        re.compile(r'^\s*([A-Za-z0-9_@.]+)\s*\{\s*(.*?)\s*\},', re.MULTILINE),
        re.compile(r'^\s*([A-Za-z0-9_@.]+)\s*\(\{\s*(.*?)\s*\}\),', re.MULTILINE),
    )
    seen: set[str] = set()
    for pattern in patterns:
        for key, body in pattern.findall(text):
            if key in seen:
                continue
            seen.add(key)
            if key not in keep_groups:
                continue
            entry = parse_lush_props(body, color_vars)
            entry.key = key
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)
    fallback_links = {
        "IncSearch": "Search",
        "Number": "Constant",
        "Keyword": "Statement",
    }
    present = {entry.key for entry in groups}
    for key, target in fallback_links.items():
        if key in keep_groups and key not in present:
            entry = Entry(key=key, link=target)
            links[key] = target
            groups.append(entry)
    return groups, [], links


def parse_enfocado_colors(autoload_path: Path) -> dict[str, str]:
    text = read(autoload_path)
    out: dict[str, str] = {}

    dark_start = text.find("if &background ==# 'dark'")
    dark_end = text.find("else", dark_start)
    dark_block = text[dark_start:dark_end]
    for name, value in re.findall(r"let l:colors\.([A-Za-z0-9_]+)\s*=\s*\['(#[0-9A-Fa-f]{6,8}|NONE)'", dark_block):
        if value != "NONE":
            out[name] = value

    style_start = text.find("if g:enfocado_style ==# 'nature'")
    style_end = text.find("\" Colors return.", style_start)
    style_block = text[style_start:style_end]
    for name, alias in re.findall(r"let l:colors\.([A-Za-z0-9_]+)\s*=\s*l:colors\.([A-Za-z0-9_]+)", style_block):
        if alias in out:
            out[name] = out[alias]
    return out


def parse_enfocado_ref(arg: str, colors: dict[str, str]) -> str | None:
    arg = arg.strip()
    match = re.match(r"s:([A-Za-z0-9_]+)", arg)
    if match:
        return colors.get(match.group(1))
    return None


def extract_enfocado(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    colors = parse_enfocado_colors(theme_root / "autoload/enfocado.vim")
    text = read(theme_root / "colors/enfocado.vim")
    groups: list[Entry] = []
    links: dict[str, str] = {}
    keep_groups = set(AUDIT_EDITOR_GROUPS) | set(AUDIT_SYNTAX_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineWarn",
        "ErrorMsg",
        "Function",
        "Identifier",
        "LineNr",
        "MatchParen",
        "MoreMsg",
        "Number",
        "Operator",
        "Search",
        "String",
        "Title",
        "Todo",
        "Type",
        "Visual",
        "WarningMsg",
    }
    pattern = re.compile(r"call enfocado#highlighter\('([^']+)'\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)")
    for group, attr_arg, bg_arg, fg_arg, sp_arg in pattern.findall(text):
        if group not in keep_groups:
            continue
        entry = Entry(key=group)
        attr_match = re.match(r"s:([A-Za-z0-9_]+)", attr_arg.strip())
        if attr_match:
            attr_name = attr_match.group(1)
            if attr_name in {"bold", "italic", "underline", "undercurl", "reverse", "strikethrough"}:
                entry.flags[attr_name] = True
            elif attr_name == "bold_underline":
                entry.flags["bold"] = True
                entry.flags["underline"] = True
            elif attr_name == "nocombine":
                entry.flags["nocombine"] = True
        entry.bg = parse_enfocado_ref(bg_arg, colors)
        entry.fg = parse_enfocado_ref(fg_arg, colors)
        entry.sp = parse_enfocado_ref(sp_arg, colors)
        if entry.style_only():
            groups.append(entry)
    for source, target in re.findall(r"highlight!\s+link\s+([A-Za-z0-9_@.]+)\s+([A-Za-z0-9_@.]+)", text):
        if source in keep_groups:
            links[source] = target
    present = {entry.key for entry in groups}
    fallback_links = {
        "Number": "Constant",
        "Keyword": "Statement",
        "Operator": "Statement",
    }
    for key, target in fallback_links.items():
        if key not in present:
            links[key] = target
            groups.append(Entry(key=key, link=target))
    return groups, [], links


def parse_catppuccin_entry(key: str, body: str, palette: dict[str, str], inherited_flags: dict[str, bool] | None = None) -> Entry:
    entry = Entry(key=key)
    inherited_flags = inherited_flags or {}
    for flag_name, enabled in inherited_flags.items():
        if enabled:
            entry.flags[flag_name] = True
    for flag_name, enabled in parse_style_list(body).items():
        if enabled:
            entry.flags[flag_name] = True
    for flag_name in STYLE_KEYS:
        if parse_bool_flag(body, flag_name):
            entry.flags[flag_name] = True
    link = parse_link(body)
    if link is not None:
        entry.link = link
    for color_name in ("fg", "bg", "sp"):
        literal = parse_color_literal(body, color_name)
        if literal is not None and literal != "NONE":
            setattr(entry, color_name, literal)
            continue
        match = re.search(rf"\b{color_name}\s*=\s*C\.([A-Za-z0-9_]+)", body)
        if match and match.group(1) in palette:
            setattr(entry, color_name, palette[match.group(1)])
            continue
        expr_match = re.search(rf"\b{color_name}\s*=\s*([^,\n]+)", body)
        if expr_match:
            symbol_match = re.search(r"C\.([A-Za-z0-9_]+)", expr_match.group(1))
            if symbol_match and symbol_match.group(1) in palette:
                setattr(entry, color_name, palette[symbol_match.group(1)])
    return entry


def extract_catppuccin(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    palette = catppuccin_palette(theme_root / "lua/catppuccin/palettes/mocha.lua")
    init_text = read(theme_root / "lua/catppuccin/init.lua")
    comment_flags = {"italic": 'comments = { "italic" }' in init_text}
    conditional_flags = {"italic": 'conditionals = { "italic" }' in init_text}
    syntax_entries = scan_entries(read(theme_root / "lua/catppuccin/groups/syntax.lua"))
    editor_entries = scan_entries(read(theme_root / "lua/catppuccin/groups/editor.lua"))
    tree_entries = scan_entries(read(theme_root / "lua/catppuccin/groups/treesitter.lua"))

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    style_binding = {
        "Comment": comment_flags,
        "Conditional": conditional_flags,
    }
    keep_groups = {
        *AUDIT_EDITOR_GROUPS,
        "Boolean",
        "Comment",
        "Conditional",
        "Delimiter",
        "Function",
        "Keyword",
        "Number",
        "Operator",
        "Statement",
        "String",
        "Tag",
        "Underlined",
        "Type",
        "Bold",
        "Italic",
        "Todo",
        "markdownHeadingDelimiter",
        "markdownLinkText",
    }
    for key, body in syntax_entries + editor_entries:
        inherited = style_binding.get(key, {})
        entry = parse_catppuccin_entry(key, body, palette, inherited_flags=inherited)
        if key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)

    keep_captures = {
        "@comment",
        "@module",
        "@variable",
        "@variable.builtin",
        "@variable.parameter",
        "@variable.member",
        "@constant",
        "@constant.builtin",
        "@string",
        "@string.special.url",
        "@type",
        "@type.builtin",
        "@property",
        "@function",
        "@function.builtin",
        "@function.call",
        "@function.method",
        "@function.method.call",
        "@function.macro",
        "@keyword",
        "@keyword.function",
        "@keyword.operator",
        "@keyword.import",
        "@keyword.repeat",
        "@keyword.return",
        "@operator",
        "@punctuation.delimiter",
        "@punctuation.bracket",
        "@tag",
        "@comment",
        "@comment.error",
        "@comment.warning",
        "@comment.hint",
        "@comment.todo",
        "@comment.note",
        "@markup.strong",
        "@markup.italic",
        "@markup.strikethrough",
        "@markup.underline",
        "@markup.heading",
        "@markup.heading.markdown",
        "@markup.link",
        "@markup.link.label",
        "@markup.link.url",
        "@markup.raw",
        "@markup.list",
        "@markup.list.checked",
        "@markup.list.unchecked",
        "@tag.attribute",
    }
    for key, body in tree_entries:
        entry = parse_catppuccin_entry(key, body, palette)
        if key in keep_captures or (key.startswith("@markup.heading.") and key.endswith(".markdown")):
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                captures.append(entry)

    return groups, captures, links


def extract_rose_pine(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    palette = rose_pine_palette(theme_root / "lua/rose-pine/palette.lua")
    group_colors = rose_pine_group_colors(theme_root / "lua/rose-pine/config.lua", palette)
    entries = scan_entries(read(theme_root / "lua/rose-pine.lua"))

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    keep_groups = {
        *AUDIT_EDITOR_GROUPS,
        "Boolean",
        "Comment",
        "Conditional",
        "Delimiter",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineWarn",
        "Function",
        "Keyword",
        "markdownH1",
        "markdownH2",
        "markdownH3",
        "markdownH4",
        "markdownH5",
        "markdownH6",
        "markdownLinkText",
        "markdownUrl",
        "Number",
        "Operator",
        "Statement",
        "String",
        "Tag",
        "Todo",
        "Type",
        "Underlined",
    }
    keep_captures = {
        "@comment",
        "@comment.error",
        "@comment.hint",
        "@comment.info",
        "@comment.note",
        "@comment.todo",
        "@comment.warning",
        "@constant",
        "@constant.builtin",
        "@function",
        "@function.builtin",
        "@function.macro",
        "@function.method",
        "@function.method.call",
        "@keyword",
        "@keyword.conditional",
        "@keyword.conditional.ternary",
        "@keyword.debug",
        "@keyword.directive",
        "@keyword.directive.define",
        "@keyword.exception",
        "@keyword.import",
        "@keyword.operator",
        "@keyword.repeat",
        "@keyword.return",
        "@markup.heading",
        "@markup.heading.1.markdown",
        "@markup.heading.2.markdown",
        "@markup.heading.3.markdown",
        "@markup.heading.4.markdown",
        "@markup.heading.5.markdown",
        "@markup.heading.6.markdown",
        "@markup.italic",
        "@markup.link.label.markdown_inline",
        "@markup.link.markdown_inline",
        "@markup.link.url",
        "@markup.list",
        "@markup.list.checked",
        "@markup.list.unchecked",
        "@markup.strikethrough",
        "@markup.strong",
        "@markup.underline",
        "@module",
        "@number",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.escape",
        "@string.regexp",
        "@string.special.url",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@variable",
        "@variable.builtin",
        "@variable.member",
        "@variable.parameter",
    }

    for key, body in entries:
        entry = parse_rose_pine_entry(key, body, palette, group_colors)
        if key.startswith("@"):
            if key in keep_captures:
                if entry.link:
                    links[key] = entry.link
                if entry.style_only():
                    captures.append(entry)
        elif key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)

    return groups, captures, links


def extract_onedark(theme_root: Path) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    palette = onedark_palette(theme_root / "lua/onedark/palette.lua", "dark")
    style_defaults = onedark_default_styles(theme_root / "lua/onedark/init.lua")
    text = read(theme_root / "lua/onedark/highlights.lua")

    common_match = re.search(r"hl\.common\s*=\s*\{(.*?)\n\}", text, re.DOTALL)
    syntax_match = re.search(r"hl\.syntax\s*=\s*\{(.*?)\n\}", text, re.DOTALL)
    tree_match = re.search(r"hl\.treesitter\s*=\s*\{(.*?)\n\s*\}", text, re.DOTALL)
    lsp_match = re.search(r"hl\.plugins\.lsp\s*=\s*\{(.*?)\n\}", text, re.DOTALL)
    if not common_match or not syntax_match or not tree_match or not lsp_match:
        raise SystemExit("failed to locate onedark highlight sections")

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    keep_groups = set(AUDIT_EDITOR_GROUPS) | {
        "Boolean",
        "Comment",
        "Conditional",
        "Delimiter",
        "DiagnosticUnderlineError",
        "DiagnosticUnderlineHint",
        "DiagnosticUnderlineInfo",
        "DiagnosticUnderlineWarn",
        "Function",
        "Keyword",
        "Number",
        "Operator",
        "Statement",
        "String",
        "Tag",
        "Todo",
        "Type",
    }
    keep_captures = {
        "@comment",
        "@comment.documentation",
        "@comment.error",
        "@comment.note",
        "@comment.todo",
        "@comment.warning",
        "@constant",
        "@constant.builtin",
        "@constant.macro",
        "@function",
        "@function.builtin",
        "@function.call",
        "@function.macro",
        "@function.method",
        "@function.method.call",
        "@keyword",
        "@keyword.conditional",
        "@keyword.conditional.ternary",
        "@keyword.coroutine",
        "@keyword.debug",
        "@keyword.directive",
        "@keyword.directive.define",
        "@keyword.exception",
        "@keyword.function",
        "@keyword.import",
        "@keyword.modifier",
        "@keyword.operator",
        "@keyword.repeat",
        "@keyword.return",
        "@keyword.type",
        "@markup.strong",
        "@markup.italic",
        "@markup.strikethrough",
        "@markup.underline",
        "@markup.heading",
        "@markup.heading.1",
        "@markup.heading.2",
        "@markup.heading.3",
        "@markup.heading.4",
        "@markup.heading.5",
        "@markup.heading.6",
        "@markup.link",
        "@markup.link.label",
        "@markup.link.url",
        "@markup.list",
        "@markup.list.checked",
        "@markup.list.unchecked",
        "@markup.quote",
        "@markup.raw",
        "@markup.raw.block",
        "@module",
        "@module.builtin",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.documentation",
        "@string.escape",
        "@string.regexp",
        "@string.special",
        "@string.special.path",
        "@string.special.symbol",
        "@string.special.url",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@type.definition",
        "@variable",
        "@variable.builtin",
        "@variable.member",
        "@variable.parameter",
    }

    for key, body in scan_entries(common_match.group(1)):
        entry = parse_onedark_entry(key, body, palette, style_defaults)
        if key in keep_groups and entry.style_only():
            groups.append(entry)

    for key, body in scan_entries(syntax_match.group(1)):
        entry = parse_onedark_entry(key, body, palette, style_defaults)
        if key in keep_groups and entry.style_only():
            groups.append(entry)

    for key, body in scan_entries(tree_match.group(1)):
        entry = parse_onedark_entry(key, body, palette, style_defaults)
        if key in keep_captures:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                captures.append(entry)

    for key, body in scan_entries(lsp_match.group(1)):
        if not key.startswith("DiagnosticUnderline"):
            continue
        entry = parse_onedark_entry(key, body, palette, style_defaults)
        if entry.style_only():
            groups.append(entry)

    present = {entry.key for entry in groups}
    fallback_links = {
        "Number": "Boolean",
        "Type": "Statement",
        "Operator": "Keyword",
    }
    for key, target in fallback_links.items():
        if key not in present:
            links[key] = target
            groups.append(Entry(key=key, link=target))

    return groups, captures, links


def extract_onedarkpro(theme_root: Path, variant: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    theme_path = theme_root / f"lua/onedarkpro/themes/{variant}.lua"
    palette = onedarkpro_palette(theme_path)
    generated = onedarkpro_generated(theme_path)
    editor_entries = scan_entries(read(theme_root / "lua/onedarkpro/highlights/editor.lua"))
    syntax_entries = scan_entries(read(theme_root / "lua/onedarkpro/highlights/syntax.lua"))
    tree_entries = scan_entries(read(theme_root / "lua/onedarkpro/highlights/plugins/treesitter.lua"))

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    keep_groups = {
        "Bold",
        "Boolean",
        "Comment",
        "Conditional",
        "CursorLine",
        "CursorLineNr",
        "Delimiter",
        "Function",
        "Italic",
        "IncSearch",
        "Keyword",
        "LineNr",
        "MatchParen",
        "Number",
        "Operator",
        "Search",
        "Statement",
        "String",
        "Todo",
        "Type",
        "Underlined",
        "Visual",
    }
    keep_captures = {
        "@comment",
        "@comment.error",
        "@comment.note",
        "@comment.todo",
        "@comment.warning",
        "@constant",
        "@constant.builtin",
        "@constant.macro",
        "@function",
        "@function.builtin",
        "@function.call",
        "@function.macro",
        "@function.method",
        "@function.method.call",
        "@keyword",
        "@keyword.conditional",
        "@keyword.exception",
        "@keyword.function",
        "@keyword.import",
        "@keyword.operator",
        "@keyword.repeat",
        "@keyword.return",
        "@markup.heading",
        "@markup.italic",
        "@markup.link.label",
        "@markup.link.url",
        "@markup.list",
        "@markup.list.checked",
        "@markup.list.unchecked",
        "@markup.raw",
        "@markup.raw.delimiter",
        "@markup.strikethrough",
        "@markup.strong",
        "@markup.underline",
        "@module",
        "@operator",
        "@property",
        "@punctuation.bracket",
        "@punctuation.delimiter",
        "@string",
        "@string.escape",
        "@string.regex",
        "@string.special",
        "@string.special.symbol",
        "@string.special.url",
        "@tag",
        "@tag.attribute",
        "@tag.delimiter",
        "@type",
        "@type.builtin",
        "@type.definition",
        "@type.qualifier",
        "@variable",
        "@variable.builtin",
        "@variable.member",
        "@variable.parameter",
    }

    for key, body in editor_entries:
        entry = parse_onedarkpro_entry(key, body, palette, generated)
        if key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)

    for key, body in syntax_entries:
        entry = parse_onedarkpro_entry(key, body, palette, generated)
        if key in keep_groups:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                groups.append(entry)

    for key, body in tree_entries:
        entry = parse_onedarkpro_entry(key, body, palette, generated)
        if key in keep_captures:
            if entry.link:
                links[key] = entry.link
            if entry.style_only():
                captures.append(entry)

    return groups, captures, links


def render_entry(entry: Entry) -> str:
    parts: list[str] = []
    if entry.fg:
        parts.append(f'fg = "{entry.fg}"')
    if entry.bg:
        parts.append(f'bg = "{entry.bg}"')
    if entry.sp:
        parts.append(f'sp = "{entry.sp}"')
    if entry.link:
        parts.append(f'link = "{entry.link}"')
    for flag_name in STYLE_KEYS:
        if entry.flags.get(flag_name):
            parts.append(f"{flag_name} = true")
    if not parts:
        return ""
    key = f'["{entry.key}"]' if entry.key.startswith("@") else entry.key
    return f"                {key} = {{ " + ", ".join(parts) + " },"


def dedupe_entries(entries: list[Entry]) -> list[Entry]:
    ordered: dict[str, Entry] = {}
    for entry in entries:
        ordered[entry.key] = entry
    return list(ordered.values())


def render_overlay(theme_name: str, groups: list[Entry], captures: list[Entry], links: dict[str, str]) -> str:
    groups = dedupe_entries(groups)
    captures = dedupe_entries(captures)
    lines = [
        f"-- Generated by tools/editor_theme_import.py for {theme_name}",
        "return {",
        "    editor = {",
        "        theme = {",
    ]
    if groups:
        lines.append("            groups = {")
        for entry in sorted(groups, key=lambda e: e.key.lower()):
            rendered = render_entry(entry)
            if rendered:
                lines.append(rendered)
        lines.append("            },")
    if captures:
        lines.append("            captures = {")
        for entry in sorted(captures, key=lambda e: e.key):
            rendered = render_entry(entry)
            if rendered:
                lines.append(rendered)
        lines.append("            },")
    if links:
        lines.append("            links = {")
        for key in sorted(links):
            target = links[key]
            rendered_key = f'["{key}"]' if key.startswith("@") else key
            lines.append(f'                {rendered_key} = "{target}",')
        lines.append("            },")
    lines.extend([
        "        },",
        "    },",
        "}",
    ])
    return "\n".join(lines)


def payload_to_entry(key: str, payload: object) -> Entry | None:
    if not isinstance(payload, dict):
        return None
    entry = Entry(key=key)
    for color_name in ("fg", "bg", "sp"):
        value = payload.get(color_name)
        if isinstance(value, str) and value.startswith("#"):
            setattr(entry, color_name, value)
    for flag_name in STYLE_KEYS:
        if payload.get(flag_name) is True:
            entry.flags[flag_name] = True
    if payload.get("link") and isinstance(payload["link"], str):
        entry.link = payload["link"]
    return entry if entry.style_only() else None


def should_skip_resolved_name(name: str) -> bool:
    return name.startswith("@lsp.")


CORE_GROUP_PREFIXES = (
    "Diagnostic",
    "Diff",
)

CORE_GROUP_NAMES = {
    "Added",
    "Bold",
    "Boolean",
    "Character",
    "ColorColumn",
    "Comment",
    "Conditional",
    "Constant",
    "Cursor",
    "CursorLine",
    "CursorLineNr",
    "Delimiter",
    "Error",
    "ErrorMsg",
    "Exception",
    "Float",
    "Function",
    "Identifier",
    "IncSearch",
    "Include",
    "Italic",
    "Keyword",
    "Label",
    "LineNr",
    "Macro",
    "MatchParen",
    "Normal",
    "NormalFloat",
    "Number",
    "Operator",
    "PreProc",
    "Removed",
    "Repeat",
    "Search",
    "Special",
    "SpecialChar",
    "Statement",
    "String",
    "Structure",
    "Title",
    "Todo",
    "Type",
    "Typedef",
    "Underlined",
    "Visual",
    "WarningMsg",
    *AUDIT_EDITOR_GROUPS,
    *AUDIT_SYNTAX_GROUPS,
}

CORE_CAPTURE_PREFIXES = (
    "@attribute",
    "@comment",
    "@constant",
    "@constructor",
    "@function",
    "@keyword",
    "@label",
    "@markup",
    "@module",
    "@number",
    "@operator",
    "@property",
    "@punctuation",
    "@string",
    "@tag",
    "@type",
    "@variable",
)


def keep_group_in_pruned_resolved_overlay(name: str) -> bool:
    if name in CORE_GROUP_NAMES:
        return True
    return any(name.startswith(prefix) for prefix in CORE_GROUP_PREFIXES)


def keep_capture_in_pruned_resolved_overlay(name: str) -> bool:
    return any(name.startswith(prefix) for prefix in CORE_CAPTURE_PREFIXES)


def extract_parts_from_resolved_export(path: Path, prune: str) -> tuple[str, list[Entry], list[Entry], dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    aggregate = data.get("aggregate")
    if not isinstance(aggregate, dict):
        raise SystemExit(f"resolved export missing aggregate snapshot: {path}")

    theme_name = data.get("metadata", {}).get("colorscheme")
    if not isinstance(theme_name, str) or not theme_name:
        raise SystemExit(f"resolved export missing metadata.colorscheme: {path}")

    groups: list[Entry] = []
    captures: list[Entry] = []
    links: dict[str, str] = {}

    raw_groups = aggregate.get("groups", {})
    if isinstance(raw_groups, dict):
        for key, payload in raw_groups.items():
            if not isinstance(key, str) or should_skip_resolved_name(key):
                continue
            if prune == "editor-surface" and not keep_group_in_pruned_resolved_overlay(key):
                continue
            entry = payload_to_entry(key, payload)
            if entry is not None:
                groups.append(entry)

    raw_captures = aggregate.get("captures", {})
    if isinstance(raw_captures, dict):
        for key, payload in raw_captures.items():
            if not isinstance(key, str) or should_skip_resolved_name(key):
                continue
            if prune == "editor-surface" and not keep_capture_in_pruned_resolved_overlay(key):
                continue
            entry = payload_to_entry(key, payload)
            if entry is not None:
                captures.append(entry)

    raw_links = aggregate.get("links", {})
    if isinstance(raw_links, dict):
        for key, target in raw_links.items():
            if not isinstance(key, str) or not isinstance(target, str):
                continue
            if should_skip_resolved_name(key) or should_skip_resolved_name(target):
                continue
            links[key] = target

    if prune == "editor-surface":
        kept_group_keys = {entry.key for entry in groups}
        kept_capture_keys = {entry.key for entry in captures}
        filtered_links: dict[str, str] = {}
        for key, target in links.items():
            source_kept = key in kept_group_keys or key in kept_capture_keys or keep_group_in_pruned_resolved_overlay(key) or keep_capture_in_pruned_resolved_overlay(key)
            target_kept = target in kept_group_keys or target in kept_capture_keys or keep_group_in_pruned_resolved_overlay(target) or keep_capture_in_pruned_resolved_overlay(target)
            if source_kept and target_kept:
                filtered_links[key] = target
        links = filtered_links

    return theme_name, groups, captures, links


def extract_parts(theme: str) -> tuple[list[Entry], list[Entry], dict[str, str]]:
    if theme == "tokyonight-night":
        groups, captures, links = extract_tokyonight(HOME / ".local/share/nvim/lazy/tokyonight.nvim")
    elif theme == "ayu":
        groups, captures, links = extract_ayu(HOME / ".local/share/nvim/lazy/neovim-ayu")
    elif theme == "catppuccin-mocha":
        groups, captures, links = extract_catppuccin(HOME / ".local/share/nvim/lazy/catppuccin")
    elif theme == "everforest-dark":
        groups, captures, links = extract_vimscript_theme(
            HOME / ".local/share/nvim/lazy/everforest/autoload/everforest.vim",
            HOME / ".local/share/nvim/lazy/everforest/colors/everforest.vim",
            "everforest",
            "everforest#get_palette",
        )
    elif theme == "gruvbox-dark":
        groups, captures, links = extract_gruvbox(HOME / ".local/share/nvim/lazy/gruvbox.nvim")
    elif theme == "jellybeans-dark":
        groups, captures, links = extract_lush_literal_theme(HOME / ".local/share/nvim/lazy/jellybeans-nvim", "lua/lush_theme/jellybeans-nvim.lua")
    elif theme == "rose-pine-main":
        groups, captures, links = extract_rose_pine(HOME / ".local/share/nvim/lazy/rose-pine")
    elif theme == "material-oceanic":
        groups, captures, links = extract_material(HOME / ".local/share/nvim/lazy/material.nvim")
    elif theme == "monokai-classic":
        groups, captures, links = extract_monokai(HOME / ".local/share/nvim/lazy/monokai.nvim", "classic")
    elif theme == "monokai-pro":
        groups, captures, links = extract_monokai(HOME / ".local/share/nvim/lazy/monokai.nvim", "pro")
    elif theme == "monokai-ristretto":
        groups, captures, links = extract_monokai(HOME / ".local/share/nvim/lazy/monokai.nvim", "ristretto")
    elif theme == "monokai-soda":
        groups, captures, links = extract_monokai(HOME / ".local/share/nvim/lazy/monokai.nvim", "soda")
    elif theme == "onedark-dark":
        groups, captures, links = extract_onedark(HOME / ".local/share/nvim/lazy/onedark.nvim")
    elif theme == "onedarkpro-onedark":
        groups, captures, links = extract_onedarkpro(HOME / ".local/share/nvim/lazy/onedarkpro.nvim", "onedark")
    elif theme == "onedarkpro-onedark-vivid":
        groups, captures, links = extract_onedarkpro(HOME / ".local/share/nvim/lazy/onedarkpro.nvim", "onedark_vivid")
    elif theme == "vaporwave":
        groups, captures, links = extract_onedarkpro(HOME / ".local/share/nvim/lazy/onedarkpro.nvim", "vaporwave")
    elif theme == "kanagawa-dragon":
        groups, captures, links = extract_kanagawa(HOME / ".local/share/nvim/lazy/kanagawa-dragon")
    elif theme == "modus-vivendi":
        groups, captures, links = extract_modus(HOME / ".local/share/nvim/lazy/modus-themes.nvim", "modus_vivendi")
    elif theme == "moonfly-dark":
        groups, captures, links = extract_fly_theme(HOME / ".local/share/nvim/lazy/moonfly", "moonfly")
    elif theme == "nightfly-dark":
        groups, captures, links = extract_nightfly(HOME / ".local/share/nvim/lazy/nightfly")
    elif theme == "noctis-dark":
        groups, captures, links = extract_lush_literal_theme(HOME / ".local/share/nvim/lazy/noctis.nvim", "lua/lush_theme/noctis.lua")
    elif theme == "poimandres-main":
        groups, captures, links = extract_poimandres(HOME / ".local/share/nvim/lazy/poimandres.nvim")
    elif theme == "sonokai-default":
        groups, captures, links = extract_vimscript_theme(
            HOME / ".local/share/nvim/lazy/sonokai/autoload/sonokai.vim",
            HOME / ".local/share/nvim/lazy/sonokai/colors/sonokai.vim",
            "sonokai",
            "sonokai#get_palette",
        )
    elif theme == "vim-enfocado-dark":
        groups, captures, links = extract_enfocado(HOME / ".local/share/nvim/lazy/vim-enfocado")
    else:
        raise SystemExit(f"unsupported theme: {theme}")
    return groups, captures, links


def extract(theme: str) -> str:
    groups, captures, links = extract_parts(theme)
    return render_overlay(theme, groups, captures, links)


def print_supported_themes() -> None:
    for theme in SUPPORTED_THEMES:
        print(theme)


def describe_theme(theme: str) -> None:
    print(theme)
    for source in THEME_SOURCES[theme]:
        print(f"  {source}")


def coverage_report(groups: list[Entry], captures: list[Entry], links: dict[str, str]) -> CoverageReport:
    group_map = {entry.key: entry for entry in dedupe_entries(groups)}
    capture_entries = dedupe_entries(captures)
    missing_editor = [name for name in AUDIT_EDITOR_GROUPS if name not in group_map]
    missing_syntax = [name for name in AUDIT_SYNTAX_GROUPS if name not in group_map]
    present_styles = sorted({
        flag
        for entry in list(group_map.values()) + capture_entries
        for flag, enabled in entry.flags.items()
        if enabled
    })
    return CoverageReport(
        groups=len(group_map),
        captures=len(capture_entries),
        links=len(links),
        missing_editor=missing_editor,
        missing_syntax=missing_syntax,
        present_styles=present_styles,
    )


def print_coverage_block(prefix: str, report: CoverageReport) -> None:
    print(f"{prefix}groups={report.groups} captures={report.captures} links={report.links}")
    print(f"{prefix}editor ui status: {report.ui_status()} ({report.editor_missing_count}/{len(AUDIT_EDITOR_GROUPS)} missing)")
    print(f"{prefix}syntax status: {report.syntax_status()} ({report.syntax_missing_count}/{len(AUDIT_SYNTAX_GROUPS)} missing)")
    print(f"{prefix}missing editor groups: {', '.join(report.missing_editor) if report.missing_editor else 'none'}")
    print(f"{prefix}missing syntax groups: {', '.join(report.missing_syntax) if report.missing_syntax else 'none'}")
    print(f"{prefix}style flags present: {', '.join(report.present_styles) if report.present_styles else 'none'}")


def audit_themes() -> int:
    print("theme importer audit")
    print()

    incomplete_editor: list[str] = []
    no_style_flags: list[str] = []

    for theme in SUPPORTED_THEMES:
        groups, captures, links = extract_parts(theme)
        report = coverage_report(groups, captures, links)
        if report.missing_editor:
            incomplete_editor.append(theme)
        if not report.present_styles:
            no_style_flags.append(theme)

        print(f"{theme}")
        print_coverage_block("  ", report)
        print()

    print("summary")
    print(f"  themes with incomplete editor UI coverage: {', '.join(incomplete_editor) if incomplete_editor else 'none'}")
    print(f"  themes with no style flags at all: {', '.join(no_style_flags) if no_style_flags else 'none'}")
    return 0


def normalize_scan_root(path: Path) -> Path:
    expanded = path.expanduser().resolve()
    if (expanded / "lazy").is_dir():
        return expanded / "lazy"
    return expanded


def discover_theme_files(path: Path) -> list[Path]:
    roots = [path.expanduser().resolve()]
    candidates: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        if not root.exists():
            continue
        for child in root.rglob("*"):
            if not child.is_file():
                continue
            if child in seen:
                continue
            if child.suffix not in {".vim", ".lua"}:
                continue
            text_path = str(child)
            if any(part in text_path for part in ("/test/", "/tests/", "/spec/", "/lua/baleia/styles/", "/plugin/")):
                continue
            if (
                "/colors/" in text_path
                or "/lua/lush_theme/" in text_path
                or "/extras/lua/" in text_path
                or ("/lua/" in text_path and "theme" in child.name.lower())
            ):
                seen.add(child)
                candidates.append(child)
    return sorted(candidates)


def supported_source_paths() -> set[Path]:
    out: set[Path] = set()
    for paths in THEME_SOURCES.values():
        for path in paths:
            out.add(Path(path).expanduser().resolve())
    return out


def classify_theme_file(path: Path, supported_paths: set[Path]) -> ThemeFileProbe:
    if path in supported_paths:
        return ThemeFileProbe(path=path, shape="curated-source", status="covered", detail="used by an existing importer target")

    text = read(path)

    if re.search(r"call\s+[A-Za-z0-9_#]+highlight\(", text):
        return ThemeFileProbe(path=path, shape="vimscript-highlighter", status="generic-parser", detail="matches the generic vimscript highlight-call parser shape")
    if "exec 'highlight " in text:
        return ThemeFileProbe(path=path, shape="vimscript-exec-highlight", status="generic-parser", detail="matches the generic Vim exec-highlight parser shape")
    if "local lush = require" in text and "return {" in text:
        return ThemeFileProbe(path=path, shape="lush-literal", status="generic-parser", detail="matches the generic Lush theme parser shape")
    if re.search(r"hl\.(common|syntax|treesitter)\s*=\s*\{", text):
        return ThemeFileProbe(path=path, shape="lua-highlight-tables", status="shape-known", detail="uses Lua highlight tables, but still needs theme-specific symbol resolution")
    if re.search(r"local\s+(groups|highlights|syntax_hls|editor_hls|treesitter_hls)\s*=\s*\{", text):
        return ThemeFileProbe(path=path, shape="lua-group-table", status="shape-known", detail="uses plain Lua highlight tables, but still needs palette/config resolution")
    if "colors_name" in text or "vim.api.nvim_set_hl" in text or "nvim_set_hl" in text:
        return ThemeFileProbe(path=path, shape="theme-file", status="needs-parser", detail="looks like a theme entrypoint, but no supported generic parser shape matched")
    return ThemeFileProbe(path=path, shape="unknown", status="skip", detail="theme-like path, but no convincing theme-entrypoint markers found")


def looks_like_theme_repo(path: Path) -> bool:
    if not path.is_dir():
        return False
    if path.name in KNOWN_THEME_REPOS:
        return True
    return (path / "colors").is_dir() or (path / "lua").is_dir()


def classify_repo(path: Path) -> tuple[str | None, str]:
    name = path.name
    if name in REPO_TO_TARGETS:
        return name, "supported"
    if name in KNOWN_THEME_REPOS:
        return None, "known-theme-no-extractor"
    return None, "unknown"


def audit_root(path: Path) -> int:
    scan_root = normalize_scan_root(path)
    if not scan_root.is_dir():
        raise SystemExit(f"audit root does not exist: {scan_root}")

    repos = sorted([child for child in scan_root.iterdir() if looks_like_theme_repo(child)], key=lambda p: p.name.lower())
    supported_repo_count = 0
    supported_target_count = 0
    unsupported_known: list[str] = []
    unknown_candidates: list[str] = []
    weak_ui_targets: list[tuple[str, CoverageReport]] = []
    weak_syntax_targets: list[tuple[str, CoverageReport]] = []
    strong_targets: list[str] = []
    partial_targets: list[str] = []

    print(f"theme importer dry-run audit root: {scan_root}")
    print()

    for repo in repos:
        family, status = classify_repo(repo)
        print(repo.name)
        print(f"  repo: {repo}")
        if status == "supported" and family is not None:
            targets = REPO_TO_TARGETS[family]
            supported_repo_count += 1
            supported_target_count += len(targets)
            print(f"  status: supported by existing extractor")
            print(f"  targets: {', '.join(targets)}")
            for target in targets:
                groups, captures, links = extract_parts(target)
                report = coverage_report(groups, captures, links)
                if report.ui_status() == "weak":
                    weak_ui_targets.append((target, report))
                if report.syntax_status() == "weak":
                    weak_syntax_targets.append((target, report))
                if report.ui_status() == "strong" and report.syntax_status() == "strong":
                    strong_targets.append(target)
                else:
                    partial_targets.append(target)
                print(f"    {target}:")
                print_coverage_block("      ", report)
        elif status == "known-theme-no-extractor":
            unsupported_known.append(repo.name)
            print("  status: recognized theme repo, but no extractor exists yet")
            print("  next step: add extractor family support before non-dry-run import")
        else:
            unknown_candidates.append(repo.name)
            print("  status: not recognized as a supported theme family")
            print("  next step: inspect repo shape and decide whether it belongs in importer scope")
        print()

    print("summary")
    print(f"  scanned repos: {len(repos)}")
    print(f"  repos with existing extractor coverage: {supported_repo_count}")
    print(f"  supported generated/importable targets from this root: {supported_target_count}")
    print(f"  recognized theme repos still missing extractor support: {', '.join(unsupported_known) if unsupported_known else 'none'}")
    print(f"  strong targets (editor ui + syntax): {', '.join(sorted(strong_targets)) if strong_targets else 'none'}")
    print(f"  partial targets needing more coverage: {', '.join(sorted(partial_targets)) if partial_targets else 'none'}")
    if weak_ui_targets:
        ordered_weak_ui = sorted(weak_ui_targets, key=lambda item: (-item[1].editor_missing_count, item[0]))
        print("  weakest editor-ui targets:")
        for target, report in ordered_weak_ui[:8]:
            print(f"    {target}: missing {report.editor_missing_count}/{len(AUDIT_EDITOR_GROUPS)} -> {', '.join(report.missing_editor)}")
    else:
        print("  weakest editor-ui targets: none")
    if weak_syntax_targets:
        ordered_weak_syntax = sorted(weak_syntax_targets, key=lambda item: (-item[1].syntax_missing_count, item[0]))
        print("  weakest syntax targets:")
        for target, report in ordered_weak_syntax[:8]:
            print(f"    {target}: missing {report.syntax_missing_count}/{len(AUDIT_SYNTAX_GROUPS)} -> {', '.join(report.missing_syntax)}")
    else:
        print("  weakest syntax targets: none")
    print(f"  unclassified candidate repos: {', '.join(unknown_candidates) if unknown_candidates else 'none'}")
    return 0


def audit_theme_files_root(path: Path) -> int:
    root = path.expanduser().resolve()
    if not root.exists():
        raise SystemExit(f"audit root does not exist: {root}")

    files = discover_theme_files(root)
    supported_paths = supported_source_paths()
    probes = [classify_theme_file(path, supported_paths) for path in files]

    covered = [p for p in probes if p.status == "covered"]
    generic = [p for p in probes if p.status == "generic-parser"]
    shape_known = [p for p in probes if p.status == "shape-known"]
    needs_parser = [p for p in probes if p.status == "needs-parser"]
    skipped = [p for p in probes if p.status == "skip"]

    shape_counts: dict[str, int] = {}
    for probe in probes:
        shape_counts[probe.shape] = shape_counts.get(probe.shape, 0) + 1

    print(f"theme importer recursive file audit root: {root}")
    print()
    print(f"total theme-like files: {len(files)}")
    print(f"already covered by curated importer sources: {len(covered)}")
    print(f"matches current generic parser shapes: {len(generic)}")
    print(f"known theme-file shapes but still need more generic symbol resolution: {len(shape_known)}")
    print(f"theme entrypoints that still need a new parser shape: {len(needs_parser)}")
    print(f"theme-like files skipped as low-confidence/non-entrypoint: {len(skipped)}")
    print()
    print("shape breakdown:")
    for shape, count in sorted(shape_counts.items(), key=lambda item: (-item[1], item[0])):
        print(f"  {shape}: {count}")
    print()

    if generic:
        print("generic-parser candidates:")
        for probe in generic[:40]:
            print(f"  {probe.path}")
            print(f"    shape: {probe.shape}")
            print(f"    note: {probe.detail}")
        if len(generic) > 40:
            print(f"  ... {len(generic) - 40} more")
        print()

    if shape_known:
        print("shape-known candidates:")
        for probe in shape_known[:40]:
            print(f"  {probe.path}")
            print(f"    shape: {probe.shape}")
            print(f"    note: {probe.detail}")
        if len(shape_known) > 40:
            print(f"  ... {len(shape_known) - 40} more")
        print()

    if needs_parser:
        print("needs-parser candidates:")
        for probe in needs_parser[:40]:
            print(f"  {probe.path}")
            print(f"    shape: {probe.shape}")
            print(f"    note: {probe.detail}")
        if len(needs_parser) > 40:
            print(f"  ... {len(needs_parser) - 40} more")
        print()

    return 0


def generated_output_path(theme: str) -> Path:
    return GENERATED_DIR / f"{theme}.overlay.lua"


def remove_generated_theme_registration(theme: str) -> bool:
    if not THEME_REGISTRY_PATH.exists():
        raise SystemExit(f"missing theme registry: {THEME_REGISTRY_PATH}")

    current = THEME_REGISTRY_PATH.read_text(encoding="utf-8")
    lines = current.splitlines()
    entry_pattern = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*"([^"]+)",\s*$')

    available_start: int | None = None
    available_end: int | None = None
    entries: list[tuple[str, str]] = []
    removed = False
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if available_start is None:
            if stripped == "local available = {":
                available_start = idx
            continue
        if stripped == "}":
            available_end = idx
            break
        match = entry_pattern.match(line)
        if match is not None:
            name = match.group(1)
            path = match.group(2)
            if name == theme:
                removed = True
                continue
            entries.append((name, path))

    if available_start is None or available_end is None:
        raise SystemExit(f"failed to find available theme table in {THEME_REGISTRY_PATH}")

    if not removed:
        return False

    updated_entries = [f'\t["{name}"] = "{path}",' for name, path in sorted(entries)]
    updated = lines[: available_start + 1] + updated_entries + lines[available_end:]
    THEME_REGISTRY_PATH.write_text("\n".join(updated) + "\n", encoding="utf-8")
    return True


def register_generated_theme(theme: str) -> None:
    relative_path = f"assets/themes/generated/{theme}.overlay.lua"
    if not THEME_REGISTRY_PATH.exists():
        raise SystemExit(f"missing theme registry: {THEME_REGISTRY_PATH}")

    current = THEME_REGISTRY_PATH.read_text(encoding="utf-8")
    lines = current.splitlines()
    entry_pattern = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*"([^"]+)",\s*$')

    available_start: int | None = None
    available_end: int | None = None
    entries: list[tuple[str, str]] = []
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if available_start is None:
            if stripped == "local available = {":
                available_start = idx
            continue
        if stripped == "}":
            available_end = idx
            break
        match = entry_pattern.match(line)
        if match is not None:
            entries.append((match.group(1), match.group(2)))

    if available_start is None or available_end is None:
        raise SystemExit(f"failed to find available theme table in {THEME_REGISTRY_PATH}")

    entry_map = {name: path for name, path in entries}
    entry_map[theme] = relative_path
    updated_entries = [f'\t["{name}"] = "{path}",' for name, path in sorted(entry_map.items())]
    updated = lines[: available_start + 1] + updated_entries + lines[available_end:]
    THEME_REGISTRY_PATH.write_text("\n".join(updated) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract high-signal editor theme style overlays from local Neovim themes.")
    parser.add_argument("theme", nargs="?", choices=SUPPORTED_THEMES)
    parser.add_argument("--resolved-export", type=Path, help="Build an overlay from a resolved-theme JSON artifact and use aggregate as the source of truth.")
    parser.add_argument("--resolved-name", help="Override the theme name used when rendering an overlay from --resolved-export.")
    parser.add_argument("--resolved-prune", choices=RESOLVED_PRUNE_MODES, default="editor-surface", help="Prune resolved-export ingestion with an explicit policy. Defaults to editor-surface.")
    parser.add_argument("--list", action="store_true", help="List supported local Neovim theme importer targets.")
    parser.add_argument("--describe", action="store_true", help="Show the local source files used by the selected importer target.")
    parser.add_argument("--audit", action="store_true", help="Run a dry-run audit across all supported themes and print high-level mapping gaps.")
    parser.add_argument("--audit-root", type=Path, help="Run a dry-run audit across a full Neovim theme root (for example ~/.local/share/nvim or ~/.local/share/nvim/lazy).")
    parser.add_argument("--audit-theme-files-root", type=Path, help="Recursively scan theme-like files under a Neovim root and report generic parser coverage vs parser-shape gaps.")
    parser.add_argument("--out", type=Path, help="Write overlay to this path instead of stdout.")
    parser.add_argument("--apply", action="store_true", help="Write the generated overlay to assets/themes/generated/<theme>.overlay.lua.")
    parser.add_argument("--register", action="store_true", help="Register the generated overlay in assets/themes/init.lua so it is available through the imported-theme runtime authority.")
    parser.add_argument("--remove-generated", help="Remove a generated overlay and unregister it from assets/themes/init.lua.")
    parser.add_argument("--check", action="store_true", help="Fail if assets/themes/generated/<theme>.overlay.lua does not match generated output.")
    args = parser.parse_args()

    if args.list:
        if args.resolved_export is not None or args.resolved_name is not None or args.remove_generated is not None:
            parser.error("--resolved-export/--resolved-name/--remove-generated cannot be combined with --list")
        if args.theme is not None:
            parser.error("theme cannot be combined with --list")
        if args.out is not None or args.apply or args.check or args.register or args.describe or args.audit or args.audit_root is not None:
            parser.error("--list cannot be combined with --describe, --audit, --audit-root, --out, --apply, --register, or --check")
        print_supported_themes()
        return 0

    if args.audit:
        if args.resolved_export is not None or args.resolved_name is not None or args.remove_generated is not None:
            parser.error("--resolved-export/--resolved-name/--remove-generated cannot be combined with --audit")
        if args.theme is not None:
            parser.error("theme cannot be combined with --audit")
        if args.out is not None or args.apply or args.check or args.register or args.describe or args.audit_root is not None or args.audit_theme_files_root is not None:
            parser.error("--audit cannot be combined with --describe, --audit-root, --audit-theme-files-root, --out, --apply, --register, or --check")
        return audit_themes()

    if args.audit_root is not None:
        if args.resolved_export is not None or args.resolved_name is not None or args.remove_generated is not None:
            parser.error("--resolved-export/--resolved-name/--remove-generated cannot be combined with --audit-root")
        if args.theme is not None:
            parser.error("theme cannot be combined with --audit-root")
        if args.out is not None or args.apply or args.check or args.register or args.describe or args.audit_theme_files_root is not None:
            parser.error("--audit-root cannot be combined with --describe, --audit-theme-files-root, --out, --apply, --register, or --check")
        return audit_root(args.audit_root)

    if args.audit_theme_files_root is not None:
        if args.resolved_export is not None or args.resolved_name is not None or args.remove_generated is not None:
            parser.error("--resolved-export/--resolved-name/--remove-generated cannot be combined with --audit-theme-files-root")
        if args.theme is not None:
            parser.error("theme cannot be combined with --audit-theme-files-root")
        if args.out is not None or args.apply or args.check or args.register or args.describe:
            parser.error("--audit-theme-files-root cannot be combined with --describe, --out, --apply, --register, or --check")
        return audit_theme_files_root(args.audit_theme_files_root)

    if args.remove_generated is not None:
        if (
            args.theme is not None
            or args.resolved_export is not None
            or args.resolved_name is not None
            or args.out is not None
            or args.apply
            or args.register
            or args.check
            or args.describe
        ):
            parser.error("--remove-generated cannot be combined with theme generation or describe flags")
        removed_registry = remove_generated_theme_registration(args.remove_generated)
        target = generated_output_path(args.remove_generated)
        removed_file = False
        if target.exists():
            target.unlink()
            removed_file = True
        if removed_registry:
            print(f"unregistered {args.remove_generated} from {THEME_REGISTRY_PATH.relative_to(ROOT)}")
        if removed_file:
            print(f"removed {target.relative_to(ROOT)}")
        if not removed_registry and not removed_file:
            print(f"nothing to remove for {args.remove_generated}")
        return 0

    if args.resolved_name is not None and args.resolved_export is None:
        parser.error("--resolved-name requires --resolved-export")

    if args.resolved_export is not None:
        if args.theme is not None:
            parser.error("theme cannot be combined with --resolved-export")
        if args.describe:
            parser.error("--describe cannot be combined with --resolved-export")
    elif args.theme is None:
        parser.error("theme is required unless --list, --audit, --audit-root, --audit-theme-files-root, or --resolved-export is used")

    if args.describe:
        if args.out is not None or args.apply or args.check or args.register:
            parser.error("--describe cannot be combined with --out, --apply, --register, or --check")
        describe_theme(args.theme)
        return 0

    if args.apply and args.check:
        parser.error("--apply and --check are mutually exclusive")
    if args.register and not args.apply:
        parser.error("--register requires --apply")
    if args.out is not None and (args.apply or args.check):
        parser.error("--out cannot be combined with --apply or --check")

    if args.resolved_export is not None:
        resolved_theme_name, groups, captures, links = extract_parts_from_resolved_export(args.resolved_export, args.resolved_prune)
        render_name = args.resolved_name or resolved_theme_name
        rendered = render_overlay(render_name, groups, captures, links) + "\n"
        default_target_name = render_name
    else:
        rendered = extract(args.theme) + "\n"
        default_target_name = args.theme

    if args.check:
        target = generated_output_path(default_target_name)
        if not target.exists():
            print(f"missing generated overlay: {target}", file=sys.stderr)
            return 1
        current = target.read_text(encoding="utf-8")
        if current != rendered:
            print(f"generated overlay is out of date: {target}", file=sys.stderr)
            return 1
        return 0

    if args.apply:
        target = generated_output_path(default_target_name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(rendered, encoding="utf-8")
        if args.register:
            register_generated_theme(default_target_name)
        print(f"wrote {target.relative_to(ROOT)}")
        if args.register:
            print(f"registered {default_target_name} in {THEME_REGISTRY_PATH.relative_to(ROOT)}")
        return 0

    if args.out:
        args.out.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
