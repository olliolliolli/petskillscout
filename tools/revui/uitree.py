# Builds tools/revui/uitree_data.lua: for every window the WoW: Forever client
# loads (UIPanelWindows entries in addons allowed for the "mainline" game type,
# which Forever runs, or its "camelot" overrides,
# plus a few non-panel windows), the frame tree as the game's XML declares it:
# frames, buttons, textures (layer, atlas / file, size) and font strings
# (font object), with inherited virtual templates expanded.
# Usage: python tools/revui/uitree.py <ui-forever dir> <out .lua>
import os, re, sys, glob
import xml.etree.ElementTree as ET

UI = sys.argv[1]
OUT = sys.argv[2]
ADDONS = os.path.join(UI, "Interface", "AddOns")
NS = "{http://www.blizzard.com/wow/ui/}"
FRAME_TAGS = {"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
              "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "PlayerModel", "DressUpModel",
              "Model", "ModelScene", "ItemButton", "DropdownButton", "EventFrame", "EventButton", "ContainedAlertFrame",
              "Browser", "MovieFrame", "ColorSelect", "TabardModel", "CinematicModel", "UnitPositionFrame"}
EXTRA = ["StaticPopup1", "StackSplitFrame", "ColorPickerFrame", "BankFrame", "PetStableFrame", "TradeSkillFrame",
         "CraftFrame", "OpenMailFrame", "TimeManagerFrame", "SettingsPanel", "ReadyCheckFrame", "BattlefieldFrame",
         "WorldMapFrame", "QuestLogDetailFrame", "ProfessionsFrame", "PlayerSpellsFrame"]

def strip(tag): return tag.replace(NS, "")

allowed = {}
for d in os.listdir(ADDONS):
    tocs = glob.glob(os.path.join(ADDONS, d, "*.toc"))
    if not tocs: continue
    t = open(tocs[0], encoding="utf-8", errors="ignore").read()
    m = re.search(r"^## AllowLoadGameType:\s*(.+)$", t, re.M)
    allowed[d] = (m is None) or ("camelot" in m.group(1)) or ("mainline" in m.group(1))

# Parse every XML of allowed addons: virtual templates by name, named frames.
templates, named = {}, {}
for d, ok in allowed.items():
    if not ok: continue
    for root, _, files in os.walk(os.path.join(ADDONS, d)):
        for f in files:
            if not f.endswith(".xml"): continue
            try:
                tree = ET.parse(os.path.join(root, f))
            except ET.ParseError:
                continue
            for el in tree.getroot():
                tag = strip(el.tag)
                name = el.get("name")
                if not name: continue
                if el.get("virtual") == "true":
                    templates.setdefault(name, el)
                elif tag in FRAME_TAGS:
                    named.setdefault(name, (el, d))

panels = set()
for root, _, files in os.walk(ADDONS):
    for f in files:
        if f.endswith(".lua"):
            s = open(os.path.join(root, f), encoding="utf-8", errors="ignore").read()
            for n in re.findall(r'UIPanelWindows\["([A-Za-z0-9_]+)"\]', s): panels.add(n)
wanted = sorted(n for n in panels | set(EXTRA) if n in named)

def lua_str(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def size_of(el):
    for c in el:
        if strip(c.tag) == "Size":
            x, y = c.get("x"), c.get("y")
            return (float(x) if x else None, float(y) if y else None)
    return (None, None)

def node(el, depth, seen):
    """Frame-like element -> dict; templates from inherits expanded first."""
    tag = strip(el.tag)
    out = {"type": tag, "name": el.get("name"), "key": el.get("parentKey"), "children": [], "regions": []}
    w, h = size_of(el)
    out["w"], out["h"] = w, h
    if depth > 7: return out
    for inh in (el.get("inherits") or "").replace(" ", "").split(","):
        t = templates.get(inh)
        if t is not None and inh not in seen:
            sub = node(t, depth + 1, seen | {inh})
            out["children"] += sub["children"]; out["regions"] += sub["regions"]
            out["w"] = out["w"] or sub["w"]; out["h"] = out["h"] or sub["h"]
            out.setdefault("inherits", []).append(inh)
    for c in el:
        ct = strip(c.tag)
        if ct == "Layers":
            for layer in c:
                lv = layer.get("level") or "ARTWORK"
                for r in layer:
                    rt = strip(r.tag)
                    if rt in ("Texture", "MaskTexture", "Line"):
                        rw, rh = size_of(r)
                        if r.get("setAllPoints") == "true": rw, rh = rw or out["w"], rh or out["h"]
                        out["regions"].append({"type": "Texture", "name": r.get("name"), "key": r.get("parentKey"),
                            "layer": lv, "atlas": r.get("atlas"), "file": r.get("file"), "w": rw, "h": rh})
                    elif rt == "FontString":
                        out["regions"].append({"type": "FontString", "name": r.get("name"), "key": r.get("parentKey"),
                            "layer": lv, "font": r.get("inherits"), "text": r.get("text")})
        elif ct == "Frames":
            for f in c:
                if strip(f.tag) in FRAME_TAGS:
                    out["children"].append(node(f, depth + 1, seen))
    return out

def emit(n, ind):
    p = ind + "  "
    parts = ["type=" + lua_str(n["type"])]
    for k in ("name", "key", "layer", "atlas", "file", "font", "text"):
        if n.get(k): parts.append(k + "=" + lua_str(n[k]))
    for k in ("w", "h"):
        if n.get(k): parts.append("%s=%g" % (k, n[k]))
    if n.get("inherits"): parts.append("inherits={" + ",".join(lua_str(i) for i in n["inherits"]) + "}")
    s = "{" + ", ".join(parts)
    if n.get("regions"):
        s += ",\n" + p + "regions={" + ",\n".join(emit(r, p) for r in n["regions"]) + "}"
    if n.get("children"):
        s += ",\n" + p + "children={" + ",\n".join(emit(c, p) for c in n["children"]) + "}"
    return s + "}"

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("-- Generated by tools/revui/uitree.py from the WoW: Forever UI code (do not edit).\n")
    fh.write("UITREE = {\n")
    for n in wanted:
        el, addon = named[n]
        fh.write("[%s] = {addon=%s, tree=%s},\n" % (lua_str(n), lua_str(addon), emit(node(el, 0, set()), "  ")))
    fh.write("}\n")
print("windows:", len(wanted), "templates:", len(templates))
