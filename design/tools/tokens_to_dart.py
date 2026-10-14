#!/usr/bin/env python3
"""Regenerates lib/core/tokens.dart from design/tokens.json (the Hamduk Chess design system's
tokens). Run from the repo root:  python3 design/tools/tokens_to_dart.py
Needs only the Python standard library."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "design", "tokens.json")
OUT = os.path.join(ROOT, "lib", "core", "tokens.dart")

_t = json.load(open(SRC, encoding="utf-8"))
_themes = [th["id"] for th in _t["color"]["themes"]]


def _pair(value):
    if isinstance(value, str):
        return value, None
    return value.get("dark", value.get(_themes[0])), value.get("light")


COLORS = []
for _tok in _t["color"]["tokens"]:
    _d, _l = _pair(_tok["value"])
    if _l == _d:
        _l = None
    COLORS.append((_tok["name"], _d, _l, _tok.get("usage", "")))
SHADOWS = []
for _tok in _t["shadow"]["tokens"]:
    _d, _l = _pair(_tok["value"])
    SHADOWS.append((_tok["name"], _d, _l, _tok.get("usage", "")))
SPACING = [(x["name"], int(float(x["value"].rstrip("px"))), x.get("usage", "")) for x in _t["spacing"]["tokens"]]
RADII = [(x["name"], int(float(x["value"].rstrip("px"))), x.get("usage", "")) for x in _t["radius"]["tokens"]]
SIZES = [(x["name"], int(float(x["value"].rstrip("px"))), x.get("usage", "")) for x in _t["size"]["tokens"]]
TYPE = []
for _g in _t["type"]["groups"]:
    for _s in _g["styles"]:
        TYPE.append((_g["name"], _s.get("family", _g["family"]), _s["name"], int(float(_s["fontSize"].rstrip("px"))),
                     int(float(_s["lineHeight"].rstrip("px"))), int(_s["fontWeight"]), float(_s.get("letterSpacing", "0px").rstrip("px")),
                     _s.get("sample", ""), _s.get("usage", "")))

# ----------------------------------------------------------------------------- Flutter emitter
import re as _re


def _camel(name):
    parts = name.split("-")
    s = parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    return s


def _dart_color(v):
    v = v.strip()
    if v.startswith("#"):
        h = v[1:]
        if len(h) == 6:
            return f"Color(0xFF{h.upper()})"
        if len(h) == 8:
            return f"Color(0x{h[6:].upper()}{h[:6].upper()})"
    m = _re.fullmatch(r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\s*\)", v)
    if m:
        r, g, b, a = int(m.group(1)), int(m.group(2)), int(m.group(3)), float(m.group(4))
        return f"Color(0x{round(a * 255):02X}{r:02X}{g:02X}{b:02X})"
    raise ValueError(v)


def _shadow_list(css):
    out = []
    for part in _re.split(r",\s*(?![^()]*\))", css):
        nums = _re.findall(r"(-?\d+(?:\.\d+)?)px|(?<![\w.])0(?![\w.])", part)
        m = _re.match(r"\s*(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(-?\d+)(?:px)?(?:\s+(-?\d+)(?:px)?)?\s+(.+)$", part.strip())
        if not m:
            raise ValueError(part)
        x, y, blur, spread, color = m.group(1), m.group(2), m.group(3), m.group(4) or "0", m.group(5)
        args = [f"color: {_dart_color(color)}"]
        if x != "0" or y != "0":
            args.append(f"offset: Offset({x}, {y})")
        if blur != "0":
            args.append(f"blurRadius: {blur}")
        if spread != "0":
            args.append(f"spreadRadius: {spread}")
        out.append("BoxShadow(" + ", ".join(args) + ")")
    return out


def tokens_dart():
    themed, fixed = [], []
    for name, dark, light, usage in COLORS:
        if dark.startswith("{"):
            continue
        if light is None and name not in ("on-gold",):
            fixed.append((name, dark, usage))
        else:
            themed.append((name, dark, light if light is not None else dark, usage))
    L = []
    L.append("// GENERATED from the Hamduk Chess design system (tokens.json). Do not edit by hand:")
    L.append("// change the design system, regenerate, and replace this file.")
    L.append("// Design system: https://claude.ai/artifact/Xat88cLq3NVJra74yq2k26")
    L.append("import 'package:flutter/material.dart';")
    L.append("")
    L.append("/// Colours that change between the dark and light themes. Read them with `context.hc`.")
    L.append("@immutable")
    L.append("class HcPalette {")
    L.append("  const HcPalette({")
    L.append("    required this.brightness,")
    for n, *_ in themed:
        L.append(f"    required this.{_camel(n)},")
    L.append("  });")
    L.append("")
    L.append("  final Brightness brightness;")
    for n, d, l, u in themed:
        L.append(f"  /// {u}")
        L.append(f"  final Color {_camel(n)};")
    L.append("")
    L.append("  /// A won game (always shown with W or the word).")
    L.append("  Color get win => green;")
    L.append("  /// A lost game (always shown with L or the word).")
    L.append("  Color get loss => dangerInk;")
    L.append("  /// A drawn game (always shown with D or the word).")
    L.append("  Color get draw => ink2;")
    L.append("")
    L.append("  bool get isDark => brightness == Brightness.dark;")
    L.append("")
    L.append("  static HcPalette of(Brightness brightness) => brightness == Brightness.dark ? dark : light;")
    L.append("")
    for th, idx in (("dark", 1), ("light", 2)):
        L.append(f"  static const {th} = HcPalette(")
        L.append(f"    brightness: Brightness.{th},")
        for row in themed:
            L.append(f"    {_camel(row[0])}: {_dart_color(row[idx])},")
        L.append("  );")
        L.append("")
    L[-1:] = ["}", ""]
    L.append("/// Colours that are the same in both themes: brand, hero, board, persona stages, review.")
    L.append("abstract final class HcColors {")
    for n, v, u in fixed:
        L.append(f"  /// {u}")
        L.append(f"  static const {_camel(n)} = {_dart_color(v)};")
    L.append("}")
    L.append("")
    def num_class(cls, rows, doc, extra=()):
        L.append(f"/// {doc}")
        L.append(f"abstract final class {cls} {{")
        for n, v, u in rows:
            short = _camel(n.split("-", 1)[1]) if "-" in n else n
            if cls == "HcSpace":
                short = "s" + n.split("-")[1]
            L.append(f"  /// {u}")
            L.append(f"  static const double {short} = {v};")
        for e in extra:
            L.append(e)
        L.append("}")
        L.append("")
    num_class("HcSpace", SPACING, "The 4-point spacing scale.", ["  /// The screen gutter.", "  static const double gutter = s4;"])
    num_class("HcRadius", RADII, "Corner radii by role.")
    num_class("HcSize", SIZES, "Fixed component dimensions in logical pixels.")
    # Type
    fam = {"display": "HcFonts.display", "sans": "HcFonts.sans", "mono": "HcFonts.mono"}
    L.append("/// Font families as declared in pubspec.yaml (bundled, never fetched at runtime).")
    L.append("abstract final class HcFonts {")
    L.append("  static const display = 'PlayfairDisplay';")
    L.append("  static const sans = 'DMSans';")
    L.append("  static const mono = 'JetBrainsMono';")
    L.append("  /// Fills the letters DM Sans and Playfair lack: ẹ ọ ṣ ɓ ɗ ƙ and ₦.")
    L.append("  static const fallback = <String>['NotoSans'];")
    L.append("}")
    L.append("")
    L.append("/// The type scale. Playfair (display*) only for fixed copy at 24px and up.")
    L.append("abstract final class HcText {")
    tab = {"rating-xl", "rating-md", "clock", "clock-sm", "notation"}
    for g, f, name, size, lh, wt, ls, sample, usage in TYPE:
        args = [f"fontFamily: {fam[f]}", "fontFamilyFallback: HcFonts.fallback", f"fontSize: {size}",
                f"height: {lh / size:.4f}".rstrip("0").rstrip("."), f"fontWeight: FontWeight.w{wt}"]
        if ls:
            args.append(f"letterSpacing: {ls}")
        if name in tab:
            args.append("fontFeatures: [FontFeature.tabularFigures()]")
        L.append(f"  /// {usage} Sample: \"{sample}\".")
        L.append(f"  static const {_camel(name)} = TextStyle({', '.join(args)});")
    L.append("}")
    L.append("")
    L.append("/// Durations and curves.")
    L.append("abstract final class HcMotion {")
    L.append("  static const press = Duration(milliseconds: 120);")
    L.append("  static const state = Duration(milliseconds: 200);")
    L.append("  static const sheet = Duration(milliseconds: 320);")
    L.append("  static const pieceSlide = Duration(milliseconds: 120);")
    L.append("  /// One breath of the searching glow on a time-control tile.")
    L.append("  static const glow = Duration(milliseconds: 1200);")
    L.append("  static const enter = Curves.easeOutCubic;")
    L.append("  static const exit = Curves.easeInCubic;")
    L.append("}")
    L.append("")
    L.append("/// Elevation. CSS box-shadows from the design system, as Flutter BoxShadows.")
    L.append("abstract final class HcShadows {")
    for name, dark, light, usage in SHADOWS:
        if name == "focus-ring":
            continue
        cn = {"shadow-1": "e1", "shadow-2": "e2", "shadow-gold": "gold"}[name]
        L.append(f"  /// {usage}")
        if light is None:
            L.append(f"  static const {cn} = <BoxShadow>[{', '.join(_shadow_list(dark))}];")
        else:
            L.append(f"  static List<BoxShadow> {cn}(Brightness b) => b == Brightness.dark")
            L.append(f"      ? const [{', '.join(_shadow_list(dark))}]")
            L.append(f"      : const [{', '.join(_shadow_list(light))}];")
    L.append("  /// Keyboard and switch focus: a 2px gap in bg, then a solid 2px green ring.")
    L.append("  static List<BoxShadow> focusRing(HcPalette p) => [")
    L.append("        BoxShadow(color: p.green, spreadRadius: 4),")
    L.append("        BoxShadow(color: p.bg, spreadRadius: 2),")
    L.append("      ];")
    L.append("}")
    L.append("")
    L.append("/// The woven strip: one 24px repeat, left to right, as (colour, width).")
    L.append("abstract final class HcStrip {")
    L.append("  static const double repeat = 24;")
    L.append("  static const pattern = <(Color, double)>[")
    for c, w in [("forest", 6), ("brandGold", 3), ("brandGreen", 1), ("brandGold", 2), ("forest", 3), ("onForest", 1), ("brandGreen", 5), ("onForest", 1), ("forest", 2)]:
        L.append(f"    (HcColors.{c}, {w}),")
    L.append("  ];")
    L.append("}")
    L.append("")
    L.append("/// A board colour scheme. Overlays are shared by every theme.")
    L.append("@immutable")
    L.append("class HcBoardTheme {")
    L.append("  const HcBoardTheme({required this.id, required this.name, required this.light, required this.dark, this.plusOnly = false});")
    L.append("  final String id;")
    L.append("  final String name;")
    L.append("  final Color light;")
    L.append("  final Color dark;")
    L.append("  final bool plusOnly;")
    L.append("  Color get lastMove => HcColors.boardLastMove;")
    L.append("  Color get selected => HcColors.boardSelected;")
    L.append("  Color get moveDot => HcColors.boardMoveDot;")
    L.append("  Color get premove => HcColors.boardPremove;")
    L.append("  Color get check => HcColors.boardCheck;")
    L.append("  Color get arrow => HcColors.boardArrow;")
    L.append("}")
    L.append("")
    L.append("abstract final class HcBoardThemes {")
    L.append("  static const hamduk = HcBoardTheme(id: 'hamduk', name: 'Hamduk', light: HcColors.boardLight, dark: HcColors.boardDark);")
    L.append("  static const classic = HcBoardTheme(id: 'classic', name: 'Classic', light: HcColors.boardClassicLight, dark: HcColors.boardClassicDark);")
    L.append("  static const adire = HcBoardTheme(id: 'adire', name: 'Adire', light: HcColors.boardAdireLight, dark: HcColors.boardAdireDark, plusOnly: true);")
    L.append("  static const all = <HcBoardTheme>[hamduk, classic, adire];")
    L.append("  static HcBoardTheme byId(String? id) => all.firstWhere((t) => t.id == id, orElse: () => hamduk);")
    L.append("}")
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(tokens_dart())
    print("wrote", os.path.relpath(OUT, ROOT))
