#!/usr/bin/env python3
import os
import re
import sys


def read_table(path, table_name):
    start_re = re.compile(rf"^\s*local\s+{re.escape(table_name)}\s*=\s*{{\s*(--.*)?$")
    entries = {}
    in_table = False
    depth = 0

    def strip_strings(line):
        line = re.sub(r"'[^']*'", "''", line)
        line = re.sub(r'"[^"]*"', '""', line)
        return line

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if not in_table:
                if start_re.match(line):
                    in_table = True
                    depth = 1
                continue

            stripped = strip_strings(line)
            depth += stripped.count("{") - stripped.count("}")
            if depth <= 0:
                break

            m = re.match(r"\s*\['([^']+)'\]\s*=\s*'([^']+)'", line)
            if not m:
                m = re.match(r'\s*\["([^"]+)"\]\s*=\s*"([^"]+)"', line)
            if not m:
                m = re.match(r"\s*([A-Za-z0-9_]+)\s*=\s*'([^']+)'", line)
            if not m:
                m = re.match(r'\s*([A-Za-z0-9_]+)\s*=\s*"([^"]+)"', line)
            if m:
                entries[m.group(1)] = m.group(2)
    return entries


def parse_parsers(path):
    lang_re = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*{\s*$")
    filetype_re = re.compile(r"^\s*filetype\s*=\s*(.*)")
    langs = {}
    current = None
    in_lang = False
    lang_indent = 2
    in_filetype_list = False
    filetypes = []

    def add_filetype(ft):
        if current is None:
            return
        if current not in langs:
            langs[current] = set()
        langs[current].add(ft)

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            indent = len(line) - len(line.lstrip(" "))
            if indent == lang_indent and lang_re.match(line):
                current = lang_re.match(line).group(1)
                in_lang = True
                in_filetype_list = False
                filetypes = []
                continue

            if not in_lang:
                continue

            if indent == lang_indent and line.strip().startswith("}"):
                if current and current not in langs:
                    langs[current] = {current}
                elif current and not langs[current]:
                    langs[current] = {current}
                current = None
                in_lang = False
                in_filetype_list = False
                filetypes = []
                continue

            if in_filetype_list:
                filetypes.extend(re.findall(r"'([^']+)'", line))
                filetypes.extend(re.findall(r'"([^"]+)"', line))
                if "}" in line:
                    for ft in filetypes:
                        add_filetype(ft)
                    in_filetype_list = False
                    filetypes = []
                continue

            m = filetype_re.match(line)
            if m:
                rhs = m.group(1)
                inline = re.findall(r"'([^']+)'", rhs) + re.findall(r'"([^"]+)"', rhs)
                if "{" in rhs and "}" not in rhs:
                    in_filetype_list = True
                    filetypes.extend(inline)
                elif inline:
                    for ft in inline:
                        add_filetype(ft)
                continue

    return langs


def main():
    if len(sys.argv) != 5:
        print("Usage: generate_syntax_registry.py <filetype.lua> <parsers.lua> <output.lua> <version>")
        sys.exit(1)

    filetype_path, parsers_path, out_path, version = sys.argv[1:5]
    extensions = read_table(filetype_path, "extension")
    basenames = read_table(filetype_path, "filename")
    parser_map = parse_parsers(parsers_path)

    ft_to_parser = {}
    for parser, fts in parser_map.items():
        for ft in fts:
            if ft in ft_to_parser:
                if ft_to_parser[ft] != parser:
                    print(f"duplicate filetype mapping {ft}: {ft_to_parser[ft]} vs {parser}", file=sys.stderr)
                continue
            ft_to_parser[ft] = parser

    ext_out = {}
    for ext, ft in extensions.items():
        parser = ft_to_parser.get(ft)
        if parser:
            ext_out[ext] = parser

    base_out = {}
    for name, ft in basenames.items():
        parser = ft_to_parser.get(ft)
        if parser:
            base_out[name] = parser

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("-- Auto-generated from Neovim filetype.lua + nvim-treesitter parsers.lua\n")
        f.write(f"return {{\n  version = '{version}',\n  extensions = {{\n")
        for key in sorted(ext_out.keys()):
            val = ext_out[key]
            f.write(f"    ['{key}'] = '{val}',\n")
        f.write("  },\n  basenames = {\n")
        for key in sorted(base_out.keys()):
            val = base_out[key]
            f.write(f"    ['{key}'] = '{val}',\n")
        f.write("  },\n}\n")


if __name__ == "__main__":
    main()
