-- Every window of the WoW: Forever UI (tree from the game's own XML, see
-- uitree.py) built on the mock client, then RevUI's theme run on it. For each
-- window: Lua errors, whether it gets the theme's backdrop, Blizzard art left
-- visible (backgrounds, borders, NineSlice), and dark text left on the dark
-- theme. Usage (repo root): lua5.1 tools/revui/uisim.lua <RevUI dir> [window]
MOCK_TRACK_EARLY = true
local here = arg[0]:match("(.*/)") or ""
dofile(here .. "../tests/mock.lua")
dofile(here .. "uitree_data.lua")
local dir, only = arg[1], arg[2]

-- Mock objects with what the theme reads: regions, children, layers, art, colours.
local function Obj(kind)
  local o = MOCK.newObj(kind)
  local mt = getmetatable(o)
  o.alpha, o.regions, o.children = 1, {}, {}
  mt.m_GetObjectType = function(self) return self.kind end
  mt.m_IsObjectType = function(self, t) return self.kind == t end
  mt.m_GetRegions = function(self) return unpack(self.regions) end
  mt.m_GetChildren = function(self) return unpack(self.children) end
  mt.m_GetNumRegions = function(self) return #self.regions end
  mt.m_GetNumChildren = function(self) return #self.children end
  mt.m_SetAlpha = function(self, a) self.alpha = a end
  mt.m_GetAlpha = function(self) return self.alpha end
  mt.m_GetDrawLayer = function(self) return self.layer or "ARTWORK", 0 end
  mt.m_SetDrawLayer = function(self, l) self.layer = l end
  mt.m_GetAtlas = function(self) return self.atlas end
  mt.m_SetAtlas = function(self, a) self.atlas = a end
  mt.m_GetTexture = function(self) return self.file end
  mt.m_SetTexture = function(self, f) self.file = f end
  mt.m_GetSize = function(self) return self.w or 0, self.h or 0 end
  mt.m_GetWidth = function(self) return self.w or 0 end
  mt.m_GetHeight = function(self) return self.h or 0 end
  mt.m_SetTextColor = function(self, r, g, b) self.color = {r, g, b} end
  mt.m_GetTextColor = function(self) local c = self.color or {1, 1, 1}; return c[1], c[2], c[3], 1 end
  mt.m_SetVertexColor = function(self, r, g, b, a) self.vcolor = {r, g, b, a} end
  mt.m_GetName = function(self) return rawget(self, "_name") end
  mt.m_IsForbidden = function() return false end
  mt.m_IsProtected = function() return false end
  mt.m_CreateTexture = function(self, _, layer)
    local t = Obj("Texture"); t.layer = layer or "ARTWORK"; t.parent = self; t.ours = true
    self.regions[#self.regions + 1] = t; return t
  end
  mt.m_CreateFontString = function(self, _, layer)
    local t = Obj("FontString"); t.layer = layer or "OVERLAY"; t.parent = self; t.ours = true
    self.regions[#self.regions + 1] = t; return t
  end
  return o
end
-- Frames the theme creates (backdrops) take these methods too.
local plainCreate = CreateFrame
CreateFrame = function(kind, name, parent, template)
  local f = Obj(kind or "Frame")
  f.parent, f.name, f._name, f.ours = parent, name, name, true
  if name then _G[name] = f end
  if type(parent) == "table" and parent.children then parent.children[#parent.children + 1] = f end
  return f
end

-- Fonts the game draws dark (for parchment): on the theme they must be lightened.
local DARK_FONT = {"Black", "QuestFont", "QuestTitleFont", "Parchment", "ItemTextFontNormal", "MailTextFont",
  "InvoiceTextFont", "SubSpellFont", "GameFontDarkGraySmall"}
local function IsDarkFont(f)
  if type(f) ~= "string" then return false end
  for _, k in ipairs(DARK_FONT) do if f:find(k, 1, true) then return true end end
  return false
end

local function Build(def, parent, parentName)
  local o = Obj(def.type == "Texture" and "Texture" or def.type == "FontString" and "FontString" or
    (def.type == "CheckButton" or def.type == "Button" or def.type == "ItemButton" or def.type == "DropdownButton") and "Button"
    or def.type)
  o.parent, o.layer, o.atlas, o.file, o.w, o.h, o.font = parent, def.layer, def.atlas, def.file, def.w, def.h, def.font
  o.mapcanvas = def.mapcanvas
  if IsDarkFont(def.font) then o.color = {0.18, 0.12, 0.06} end -- as the game sets it
  local name = def.name and def.name:gsub("%$parent", parentName or "")
  if name and name ~= "" then o.name, o._name = name, name; _G[name] = o end
  if def.key and parent then parent[def.key] = o end
  for _, r in ipairs(def.regions or {}) do
    local c = Build(r, o, name or parentName)
    o.regions[#o.regions + 1] = c
  end
  for _, ch in ipairs(def.children or {}) do
    local c = Build(ch, o, name or parentName)
    o.children[#o.children + 1] = c
  end
  return o
end

-- Build every window before RevUI loads (Blizzard UI is there first in the game).
local windows = {}
for name, w in pairs(UITREE) do
  if not only or only == name then
    local ok, o = pcall(Build, w.tree, UIParent, nil)
    if ok then o.name, o._name = name, name; _G[name] = o; windows[name] = o else print("BUILD FAIL " .. name .. ": " .. tostring(o)) end
  end
end

local ns = {}
local toc = io.open(dir .. "/RevUI.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:match("^##") and line:match("%.lua$") then
    local chunk, err = loadfile(dir .. "/" .. line)
    if not chunk then print("LOAD FAIL " .. line .. ": " .. err); os.exit(1) end
    local ok, e = pcall(chunk, "RevUI", ns)
    if not ok then print("LOAD FAIL " .. line .. ": " .. tostring(e)); os.exit(1) end
  end
end
local R = RevUI
RevUIDB = RevUIDB or {}
pcall(MOCK.Fire, "ADDON_LOADED", "RevUI")
RevUIDB.skinGame = true
pcall(MOCK.Fire, "PLAYER_LOGIN")
pcall(MOCK.Fire, "PLAYER_ENTERING_WORLD", true, false)
pcall(MOCK.RunTimers)
local S = R.Skin
local errs = {}
local t0 = os.clock()
local ok, e = pcall(S.Refresh, S)
local refreshMs = (os.clock() - t0) * 1000
if not ok then errs[#errs + 1] = "Refresh: " .. tostring(e) end
-- A loading screen: the theme clears everything and puts it on again.
pcall(MOCK.Fire, "PLAYER_ENTERING_WORLD", false, true)
pcall(MOCK.RunTimers)
-- Windows show: the theme's OnShow hooks run.
for name, w in pairs(windows) do
  local h = w.scripts and w.scripts.OnShow
  if h then local ok2, e2 = pcall(h, w); if not ok2 then errs[#errs + 1] = name .. " OnShow: " .. tostring(e2) end end
end
pcall(MOCK.RunTimers)
-- The text pass runs on a 0.2 s ticker in the game: once here, windows open.
if R.SkinText and R.SkinText.Scan then
  local ok4, e4 = pcall(R.SkinText.Scan, R.SkinText)
  if not ok4 then errs[#errs + 1] = "SkinText: " .. tostring(e4) end
end

-- Report ---------------------------------------------------------------------
local ART = {"background", "border", "parchment", "ui-frame", "nineslice", "bg", "frame", "dialog", "marble", "rock"}
-- Art meant to stay: state highlights, tabs, portraits, guild banners, talent
-- animations, and plain textures the game fills in from Lua.
local KEEP = {"highlight", "-tab", "portrait", "guildbanner", "talents-animations", "flipbook", "bookicon",
  "trackingborder", "currentday"}
local function IsArt(r)
  local n = ((r.atlas or "") .. " " .. (r.file or "")):lower()
  if not r.atlas and not r.file then return false end
  for _, k in ipairs(KEEP) do if n:find(k, 1, true) then return false end end
  if r.layer == "BACKGROUND" or r.layer == "BORDER" then return true end
  for _, k in ipairs(ART) do if n:find(k, 1, true) then return true end end
  return false
end
local function Walk(o, depth, fn)
  if depth > 4 then return end
  for _, r in ipairs(o.regions or {}) do fn(r, depth) end
  for _, c in ipairs(o.children or {}) do
    if not c.ours then fn(c, depth); Walk(c, depth + 1, fn) end
  end
end
local names = {}
for n in pairs(windows) do names[#names + 1] = n end
table.sort(names)
local themed, rows = 0, {}
for _, n in ipairs(names) do
  local w = windows[n]
  local has = S:BackdropOf(w) ~= nil
  if has then themed = themed + 1 end
  local art, dark = 0, 0
  if has then
    Walk(w, 1, function(r, depth)
      if r.kind == "Texture" and not r.ours and depth <= 2 and IsArt(r) and r.alpha ~= 0 and (r.w or 0) >= 64 then art = art + 1 end
      if r.kind == "FontString" and not r.ours and r.color and (r.color[1] + r.color[2] + r.color[3]) < 1.2 then dark = dark + 1 end
    end)
  end
  rows[#rows + 1] = string.format("%-34s %-6s art left %-3d dark text %-3d %s", n, has and "themed" or "-", art, dark, UITREE[n].addon)
end
for _, r in ipairs(rows) do print(r) end
-- One window asked for: what is left, element by element.
if only and windows[only] then
  local function Path(o) local t = {}; while o and o ~= UIParent do t[#t + 1] = o.name or o.key or o.kind; o = o.parent end
    local r = {}; for i = #t, 1, -1 do r[#r + 1] = t[i] end; return table.concat(r, ".") end
  Walk(windows[only], 1, function(r, depth)
    if r.kind == "Texture" and not r.ours and depth <= 2 and IsArt(r) and r.alpha ~= 0 and (r.w or 0) >= 64 then
      print(string.format("  ART  %s  layer=%s atlas=%s file=%s %sx%s", Path(r), tostring(r.layer), tostring(r.atlas), tostring(r.file), tostring(r.w), tostring(r.h)))
    end
    if r.kind == "FontString" and not r.ours and r.color and (r.color[1] + r.color[2] + r.color[3]) < 1.2 then
      print(string.format("  DARK %s  font=%s", Path(r), tostring(r.font)))
    end
  end)
end
-- Content must stay: textures the game draws into (UICONTENT, from its Lua)
-- and every map canvas with all it holds.
local hiddenContent = {}
for wname, keys in pairs(UICONTENT or {}) do
  local w = windows[wname]
  for _, k in ipairs(keys) do
    local t = w and rawget(w, k)
    if t and t.alpha == 0 then hiddenContent[#hiddenContent + 1] = wname .. "." .. k end
  end
end
local function CanvasHidden(o, path, inCanvas)
  -- Portraits in window borders are faded on purpose (theme style).
  if tostring(rawget(o, "_name") or o.key or ""):find("Portrait") then return end
  inCanvas = inCanvas or o.mapcanvas
  if inCanvas and o.alpha == 0 and not o.ours then hiddenContent[#hiddenContent + 1] = path end
  for _, r in ipairs(o.regions or {}) do
    if inCanvas and not r.ours and r.alpha == 0 and not tostring(r.key or rawget(r, "_name") or ""):find("Portrait") then hiddenContent[#hiddenContent + 1] = path .. "." .. tostring(r.key or rawget(r, "_name") or "texture") end
  end
  for _, c in ipairs(o.children or {}) do
    if not c.ours then CanvasHidden(c, path .. "." .. tostring(c.key or rawget(c, "_name") or c.kind), inCanvas) end
  end
end
for wname, w in pairs(windows) do CanvasHidden(w, wname, false) end
for _, h in ipairs(hiddenContent) do print("HIDDEN CONTENT " .. h) end
if #hiddenContent > 0 then errs[#errs + 1] = #hiddenContent .. " content textures hidden by the theme" end
local issues = 0
for _, r in ipairs(rows) do
  local a2, d2 = r:match("art left (%d+)%s+dark text (%d+)")
  if tonumber(a2) > 0 or tonumber(d2) > 0 then issues = issues + 1 end
end
print(string.format("uisim: %d windows, %d themed, %d errors, %d windows with old art or dark text, theme pass %.0f ms", #names, themed, #errs, issues, refreshMs))
if issues > 0 then errs[#errs + 1] = issues .. " windows with old art or dark text" end
for _, e2 in ipairs(errs) do print("ERROR " .. e2) end
if #errs > 0 then os.exit(1) end
