#!/usr/bin/env python3
import argparse
import os
import re
from collections import defaultdict


def default_cache_root():
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return os.path.join(xdg, "zide", "grammars")
    home = os.environ.get("HOME")
    if home:
        return os.path.join(home, ".config", "zide", "grammars")
    return os.path.join(os.getcwd(), ".zide", "grammars")


def parse_lua_map(path):
    if not os.path.isfile(path):
        return {"extensions": {}, "basenames": {}, "globs": {}, "injections": {}}

    ext_map = {}
    base_map = {}
    glob_map = {}
    inj_map = {}
    section = None

    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("--"):
                continue
            if line.startswith("extensions"):
                section = "extensions"
                continue
            if line.startswith("basenames"):
                section = "basenames"
                continue
            if line.startswith("globs"):
                section = "globs"
                continue
            if line.startswith("injections"):
                section = "injections"
                continue
            if line.startswith("}"):
                section = None
                continue
            if section is None:
                continue

            m = re.match(r"\s*\['([^']+)'\]\s*=\s*'([^']+)'", raw)
            if not m:
                m = re.match(r'\s*\["([^"]+)"\]\s*=\s*"([^"]+)"', raw)
            if not m:
                m = re.match(r"\s*([A-Za-z0-9_]+)\s*=\s*'([^']+)'", raw)
            if not m:
                m = re.match(r'\s*([A-Za-z0-9_]+)\s*=\s*"([^"]+)"', raw)
            if not m:
                continue

            key, val = m.group(1), m.group(2)
            if section == "extensions":
                ext_map[key] = val
            elif section == "basenames":
                base_map[key] = val
            elif section == "globs":
                glob_map[key] = val
            else:
                inj_map[key] = val

    return {"extensions": ext_map, "basenames": base_map, "globs": glob_map, "injections": inj_map}


def load_maps(paths):
    merged_ext = {}
    merged_base = {}
    merged_glob = {}
    merged_inj = {}
    ext_src = {}
    base_src = {}
    glob_src = {}
    inj_src = {}
    for path in paths:
        data = parse_lua_map(path)
        for key, val in data["extensions"].items():
            merged_ext[key] = val
            ext_src[key] = path
        for key, val in data["basenames"].items():
            merged_base[key] = val
            base_src[key] = path
        for key, val in data["globs"].items():
            merged_glob[key] = val
            glob_src[key] = path
        for key, val in data["injections"].items():
            merged_inj[key] = val
            inj_src[key] = path
    return merged_ext, merged_base, merged_glob, merged_inj, ext_src, base_src, glob_src, inj_src


def invert_map(ext_map, base_map, glob_map, inj_map, ext_src, base_src, glob_src, inj_src):
    lang_exts = defaultdict(list)
    lang_bases = defaultdict(list)
    lang_globs = defaultdict(list)
    lang_inj = defaultdict(list)
    for ext, lang in ext_map.items():
        lang_exts[lang].append((ext, ext_src.get(ext)))
    for base, lang in base_map.items():
        lang_bases[lang].append((base, base_src.get(base)))
    for glob, lang in glob_map.items():
        lang_globs[lang].append((glob, glob_src.get(glob)))
    for lang, val in inj_map.items():
        lang_inj[lang].append((val, inj_src.get(lang)))
    for lang in lang_exts:
        lang_exts[lang].sort(key=lambda x: x[0])
    for lang in lang_bases:
        lang_bases[lang].sort(key=lambda x: x[0])
    for lang in lang_globs:
        lang_globs[lang].sort(key=lambda x: x[0])
    return lang_exts, lang_bases, lang_globs, lang_inj


def short_source(path, repo_root):
    if not path:
        return "unknown"
    repo_root = os.path.normpath(repo_root)
    norm = os.path.normpath(path)
    if norm.startswith(repo_root + os.sep):
        rel = os.path.relpath(norm, repo_root)
        return rel
    home = os.path.expanduser("~")
    if norm.startswith(home + os.sep):
        return "~/" + os.path.relpath(norm, home)
    return norm


def dump_lua(lang_exts, lang_bases, lang_globs, lang_inj, repo_root, out_path, grammar_langs):
    lines = []
    lines.append("return {")
    all_langs = sorted(set(grammar_langs) | set(lang_exts.keys()) | set(lang_bases.keys()) | set(lang_globs.keys()) | set(lang_inj.keys()))
    def count_for(lang):
        return len(lang_exts.get(lang, [])) + len(lang_bases.get(lang, [])) + len(lang_globs.get(lang, [])) + len(lang_inj.get(lang, []))
    all_langs.sort(key=lambda l: (count_for(l), l))
    for lang in all_langs:
        lines.append(f"  {lang} = {{")
        exts = lang_exts.get(lang, [])
        bases = lang_bases.get(lang, [])
        globs = lang_globs.get(lang, [])
        injs = lang_inj.get(lang, [])
        for ext, src in exts:
            lines.append(f"    {{ 'ext', '.{ext}', '{short_source(src, repo_root)}' }},")
        for base, src in bases:
            lines.append(f"    {{ 'basename', '{base}', '{short_source(src, repo_root)}' }},")
        for glob, src in globs:
            lines.append(f"    {{ 'glob', '{glob}', '{short_source(src, repo_root)}' }},")
        for val, src in injs:
            lines.append(f"    {{ 'injection', '{val}', '{short_source(src, repo_root)}' }},")
        lines.append("  },")
    lines.append("}")
    data = "\n".join(lines) + "\n"
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(data)
    else:
        print(data, end="")


def list_grammar_langs(root):
    if not os.path.isdir(root):
        return []
    langs = []
    for name in os.listdir(root):
        path = os.path.join(root, name)
        if os.path.isdir(path):
            langs.append(name)
    return sorted(langs)


def main():
    parser = argparse.ArgumentParser(description="Check Zide syntax mapping coverage.")
    parser.add_argument("--root", default=default_cache_root(), help="Grammar cache root")
    parser.add_argument(
        "--repo",
        default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")),
        help="Repo root",
    )
    parser.add_argument("--no-user", action="store_true", help="Ignore ~/.config/zide/syntax.lua")
    parser.add_argument("--no-project", action="store_true", help="Ignore .zide/syntax.lua in repo root")
    parser.add_argument("--dump-lua", action="store_true", help="Print Lua mapping dump to stdout")
    parser.add_argument("--dump-lua-out", help="Write Lua mapping dump to a file")
    args = parser.parse_args()

    repo_root = args.repo
    map_paths = [
        os.path.join(repo_root, "assets", "syntax", "generated.lua"),
        os.path.join(repo_root, "assets", "syntax", "overrides.lua"),
    ]

    if not args.no_user:
        xdg = os.environ.get("XDG_CONFIG_HOME")
        if xdg:
            map_paths.append(os.path.join(xdg, "zide", "syntax.lua"))
        else:
            home = os.environ.get("HOME")
            if home:
                map_paths.append(os.path.join(home, ".config", "zide", "syntax.lua"))

    if not args.no_project:
        map_paths.append(os.path.join(repo_root, ".zide", "syntax.lua"))

    ext_map, base_map, glob_map, inj_map, ext_src, base_src, glob_src, inj_src = load_maps(map_paths)
    lang_exts, lang_bases, lang_globs, lang_inj = invert_map(ext_map, base_map, glob_map, inj_map, ext_src, base_src, glob_src, inj_src)

    grammar_langs = list_grammar_langs(args.root)

    if args.dump_lua or args.dump_lua_out:
        dump_lua(lang_exts, lang_bases, lang_globs, lang_inj, repo_root, args.dump_lua_out, grammar_langs)
        if args.dump_lua_out:
            print(f"Wrote {args.dump_lua_out}")
        return
    mapped_langs = set(lang_exts.keys()) | set(lang_bases.keys()) | set(lang_globs.keys()) | set(lang_inj.keys())

    missing = [lang for lang in grammar_langs if lang not in mapped_langs]
    extra = [lang for lang in sorted(mapped_langs) if lang not in grammar_langs]

    print(f"Grammar root: {args.root}")
    print(f"Grammar languages: {len(grammar_langs)}")
    print(f"Mapped languages: {len(mapped_langs)}")

    if missing:
        print("\nUnmapped grammar languages:")
        for lang in missing:
            print(f"  - {lang}")
    else:
        print("\nAll grammar languages are mapped to at least one extension, basename, glob, or injection.")

    if extra:
        print("\nMapped languages missing grammar packs:")
        for lang in extra:
            print(f"  - {lang}")

    print("\nPer-language mapping counts:")
    for lang in grammar_langs:
        exts = len(lang_exts.get(lang, []))
        bases = len(lang_bases.get(lang, []))
        globs = len(lang_globs.get(lang, []))
        injs = len(lang_inj.get(lang, []))
        print(f"  {lang}: extensions={exts} basenames={bases} globs={globs} injections={injs}")


if __name__ == "__main__":
    main()
