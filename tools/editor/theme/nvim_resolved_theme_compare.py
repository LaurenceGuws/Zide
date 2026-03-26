#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


SYNTAX_SLOT_RULES = (
    ("comment", ("comment",)),
    ("string", ("string", "character")),
    ("keyword", ("keyword", "statement")),
    ("number", ("number",)),
    ("function", ("function", "constructor")),
    ("variable", ("variable", "identifier")),
    ("type_name", ("type", "typename")),
    ("operator", ("operator",)),
    ("builtin", ("builtin", "function.builtin", "constant.builtin", "variable.builtin")),
    ("punctuation", ("punctuation",)),
    ("constant", ("constant",)),
    ("attribute", ("attribute", "tag.attribute")),
    ("namespace", ("namespace", "module")),
    ("label", ("label",)),
    ("error", ("error",)),
    ("preproc", ("preproc",)),
    ("macro", ("macro",)),
    ("escape", ("escape", "string.escape", "character.escape")),
    ("keyword_control", ("keyword.control", "conditional", "repeat", "exception")),
    ("function_method", ("function.method", "method", "function.method.call")),
    ("type_builtin", ("type.builtin", "lsp.type.builtinType")),
)

UI_GROUP_RULES = {
    "Normal": "palette.foreground/background",
    "CursorLine": "palette.current_line",
    "Visual": "palette.selection",
    "LineNr": "palette.line_number",
    "Cursor": "palette.cursor",
}

ZIDE_STYLE_KEYS = {
    "bold",
    "italic",
    "underline",
    "undercurl",
    "strikethrough",
    "reverse",
    "nocombine",
}


def normalize_name(raw: str) -> str:
    if raw.startswith("@"):
        raw = raw[1:]
    return raw.lower().replace("-", "_").replace(" ", "_")


def syntax_slot_for(name: str) -> str | None:
    normalized = normalize_name(name)
    for slot, aliases in SYNTAX_SLOT_RULES:
        for alias in aliases:
            if normalized == alias or normalized.startswith(alias + "."):
                return slot
    return None


def lsp_slot_for(name: str) -> str | None:
    if not name.startswith("@lsp."):
        return None
    normalized = normalize_name(name)
    prefix = "lsp.type."
    if normalized.startswith(prefix):
        kind = normalized[len(prefix) :]
        lsp_map = {
            "builtintype": "type_builtin",
            "escapesequence": "escape",
            "method": "function_method",
            "function": "function",
            "keyword": "keyword_control",
            "namespace": "namespace",
            "number": "number",
            "operator": "operator",
            "regexp": "escape",
            "string": "string",
            "parameter": "variable",
            "property": "attribute",
            "comment": "comment",
            "macro": "macro",
        }
        return lsp_map.get(kind) or lsp_map.get(kind.lower())
    return None


def load_export(path: Path) -> dict:
    return json.loads(path.read_text())


def analyze_snapshot(snapshot: dict, include_lsp: bool) -> dict:
    groups = snapshot.get("groups", {})
    captures = snapshot.get("captures", {})
    links = snapshot.get("links", {})

    syntax_hits: dict[str, set[str]] = {slot: set() for slot, _ in SYNTAX_SLOT_RULES}
    raw_names = set(groups) | set(captures) | set(links)
    unmapped = []
    lsp_overlays: dict[str, list[str]] = {}
    unsupported_styles: dict[str, list[str]] = {}

    for name in sorted(raw_names):
        slot = syntax_slot_for(name)
        lsp_slot = lsp_slot_for(name)
        if slot:
            syntax_hits[slot].add(name)
        elif lsp_slot and include_lsp:
            syntax_hits[lsp_slot].add(name)
            lsp_overlays.setdefault(lsp_slot, []).append(name)

        if name in UI_GROUP_RULES or slot:
            pass
        elif lsp_slot:
            pass
        elif name.startswith("@"):
            unmapped.append((name, "capture-only"))
        else:
            unmapped.append((name, "group-only"))

    def note_styles(entries: dict[str, dict]) -> None:
        for name, payload in entries.items():
            if not isinstance(payload, dict):
                continue
            for key, value in payload.items():
                if not value or key in {"fg", "bg", "sp", "link"}:
                    continue
                if key not in ZIDE_STYLE_KEYS:
                    unsupported_styles.setdefault(key, []).append(name)

    note_styles(groups)
    note_styles(captures)

    ui_hits = {name: name in groups or name in links for name in UI_GROUP_RULES}
    return {
        "counts": snapshot.get("counts", {}),
        "syntax_hits": {slot: sorted(names) for slot, names in syntax_hits.items() if names},
        "syntax_missing": [slot for slot, _ in SYNTAX_SLOT_RULES if not syntax_hits[slot]],
        "ui_hits": ui_hits,
        "lsp_overlays": {k: sorted(v) for k, v in lsp_overlays.items()},
        "unsupported_styles": {k: sorted(v) for k, v in unsupported_styles.items()},
        "unmapped_sample": unmapped[:40],
    }


def print_report(label: str, report: dict) -> None:
    print(label)
    print(f"  counts: {report['counts']}")
    print(f"  syntax slots hit: {len(report['syntax_hits'])}/{len(SYNTAX_SLOT_RULES)}")
    if report["syntax_missing"]:
        print(f"  missing syntax slots: {', '.join(report['syntax_missing'])}")
    else:
        print("  missing syntax slots: none")
    ui_missing = [name for name, hit in report["ui_hits"].items() if not hit]
    if ui_missing:
        print(f"  missing UI groups: {', '.join(ui_missing)}")
    else:
        print("  missing UI groups: none")
    if report["unsupported_styles"]:
        print("  unsupported styles:")
        for key, names in sorted(report["unsupported_styles"].items()):
            print(f"    {key}: {', '.join(names[:8])}" + (f" ... +{len(names)-8} more" if len(names) > 8 else ""))
    else:
        print("  unsupported styles: none")
    overlay_count = sum(len(names) for names in report["lsp_overlays"].values())
    if report["lsp_overlays"]:
        print(f"  lsp overlays: {overlay_count}")
        for key, names in sorted(report["lsp_overlays"].items()):
            print(f"    {key}: {', '.join(names[:6])}" + (f" ... +{len(names)-6} more" if len(names) > 6 else ""))
    else:
        print("  lsp overlays: none")
    if report["unmapped_sample"]:
        print(f"  unmapped sample ({len(report['unmapped_sample'])} shown):")
        for name, kind in report["unmapped_sample"][:12]:
            print(f"    {name} [{kind}]")
    print()


def print_summary(data: dict) -> None:
    aggregate_with_lsp = analyze_snapshot(data["aggregate"], include_lsp=True) if "aggregate" in data else None
    aggregate_base_only = analyze_snapshot(data["aggregate"], include_lsp=False) if "aggregate" in data else None
    base_with_lsp = analyze_snapshot(data["base"], include_lsp=True) if "base" in data else None
    base_base_only = analyze_snapshot(data["base"], include_lsp=False) if "base" in data else None

    print(f"artifact: {data.get('metadata', {}).get('colorscheme')} profile={data.get('metadata', {}).get('profile')} contexts={data.get('metadata', {}).get('context_count')}")
    if base_with_lsp and base_base_only:
        print(
            "base:"
            f" syntax_with_lsp={len(base_with_lsp['syntax_hits'])}/{len(SYNTAX_SLOT_RULES)}"
            f" syntax_base_only={len(base_base_only['syntax_hits'])}/{len(SYNTAX_SLOT_RULES)}"
            f" unsupported_styles={','.join(sorted(base_with_lsp['unsupported_styles'])) or 'none'}"
        )
    if aggregate_with_lsp and aggregate_base_only:
        print(
            "aggregate:"
            f" syntax_with_lsp={len(aggregate_with_lsp['syntax_hits'])}/{len(SYNTAX_SLOT_RULES)}"
            f" syntax_base_only={len(aggregate_base_only['syntax_hits'])}/{len(SYNTAX_SLOT_RULES)}"
            f" lsp_overlay_slots={len(aggregate_with_lsp['lsp_overlays'])}"
            f" unsupported_styles={','.join(sorted(aggregate_with_lsp['unsupported_styles'])) or 'none'}"
        )
        if aggregate_base_only["syntax_missing"]:
            print("aggregate missing without lsp:", ", ".join(aggregate_base_only["syntax_missing"]))
        if aggregate_with_lsp["syntax_missing"]:
            print("aggregate missing with lsp:", ", ".join(aggregate_with_lsp["syntax_missing"]))


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare a resolved Neovim theme export against Zide's current theme surface.")
    parser.add_argument("export", type=Path, help="JSON artifact from tools/editor/theme/nvim_resolved_theme_export.lua")
    parser.add_argument("--exclude-lsp", action="store_true", help="Ignore @lsp.* names in coarse slot-fit reporting.")
    parser.add_argument("--summary", action="store_true", help="Print a compact base-vs-LSP summary.")
    args = parser.parse_args()

    data = load_export(args.export)
    if args.summary:
        print_summary(data)
        return 0

    print(f"artifact: {args.export}")
    print(f"theme: {data.get('metadata', {}).get('colorscheme')}")
    print(f"profile: {data.get('metadata', {}).get('profile')}")
    print(f"contexts: {data.get('metadata', {}).get('context_count')}")
    print(f"include_lsp: {not args.exclude_lsp}")
    print()

    if "base" in data:
        print_report("base:", analyze_snapshot(data["base"], include_lsp=not args.exclude_lsp))
    if "aggregate" in data:
        print_report("aggregate:", analyze_snapshot(data["aggregate"], include_lsp=not args.exclude_lsp))
    for context in data.get("contexts", [])[:6]:
        name = context.get("metadata", {}).get("name") or context.get("metadata", {}).get("filetype") or "context"
        print_report(f"context {name}:", analyze_snapshot(context, include_lsp=not args.exclude_lsp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
