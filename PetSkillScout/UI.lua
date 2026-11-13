-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- PetSkillScout main window (1.4.0 layout).
-- One layout for every theme; themes only change colours and textures:
--   journal  - Hunter's Journal (dark green, gold)
--   moonglade - Moonglade (deep indigo, moonlight silver-blue)
--   classic  - "WoW" (brown palette)
--   blizzard - "Classic" (stone, leather and metal textures)
-- Views: Beasts (list + details), Rare Pets (tiles), My Pet (pet card), Settings.
local PSS = PetSkillScout
PSS.UI = PSS.UI or {}
local UI = PSS.UI
local frame

local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local TEX = "Interface\\AddOns\\PetSkillScout\\Textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local WIDTH, HEIGHT, HEADER = 1100, 720, 56
local BODY_W, BODY_H = 1068, 636

---------------------------------------------------------------------------
-- Palettes
---------------------------------------------------------------------------
local BROWN = {
  background={0.095,0.073,0.050}, surface={0.170,0.130,0.084}, surfaceAlt={0.215,0.168,0.108},
  selected={0.330,0.225,0.098}, deep={0.058,0.043,0.028}, gold={0.91,0.72,0.34},
  cream={1.0,0.89,0.66}, muted={0.80,0.71,0.54}, green={0.56,0.86,0.50}, red={1.0,0.45,0.40},
  border={0.46,0.34,0.18}, dim={0.25,0.185,0.10}, ink={0.12,0.08,0.03},
}
local PALETTES = {
  journal = {
    background={0.050,0.092,0.074}, surface={0.075,0.133,0.106}, surfaceAlt={0.102,0.160,0.125},
    selected={0.122,0.200,0.157}, deep={0.039,0.075,0.059}, gold={0.851,0.698,0.427},
    cream={0.945,0.894,0.776}, muted={0.663,0.737,0.671}, green={0.561,0.878,0.627}, red={1.0,0.47,0.47},
    border={0.173,0.231,0.184}, dim={0.133,0.188,0.165}, ink={0.106,0.078,0.039},
  },
  classic = BROWN,
  blizzard = BROWN,
  -- Moonglade: Night Elf moonlight, deep indigo with silver-blue accents.
  moonglade = {
    background={0.047,0.051,0.110}, surface={0.075,0.082,0.165}, surfaceAlt={0.098,0.106,0.208},
    selected={0.133,0.141,0.278}, deep={0.035,0.039,0.086}, gold={0.63,0.78,0.98},
    cream={0.90,0.92,1.0}, muted={0.62,0.66,0.82}, green={0.56,0.90,0.78}, red={1.0,0.50,0.55},
    border={0.20,0.22,0.40}, dim={0.14,0.15,0.30}, ink={0.04,0.05,0.12},
  },
}
-- Live colour tables: widgets keep references, palettes are copied into them.
local C = {}
for k, rgb in pairs(PALETTES.journal) do C[k] = {rgb[1], rgb[2], rgb[3]} end

-- Status colours are the same in every theme.
local STATUS = {
  tamed = {bg={0.11,0.20,0.145}, fg={0.61,0.88,0.66}, edge={0.30,0.55,0.35}},
  want  = {bg={0.23,0.18,0.09},  fg={0.94,0.76,0.37}, edge={0.54,0.42,0.17}},
  new   = {bg={0.165,0.13,0.25}, fg={0.80,0.71,0.96}, edge={0.36,0.29,0.54}},
  none  = {bg={0.16,0.19,0.17},  fg={0.79,0.84,0.79}, edge=nil},
}

local function ThemeKey()
  local t = PetSkillScoutDB and PetSkillScoutDB.theme
  if t == "classic" or t == "blizzard" or t == "moonglade" then return t end
  return "journal"
end
local function Textured() return ThemeKey() == "blizzard" end
UI.ThemeKey = ThemeKey
function UI:Palette() return PALETTES[ThemeKey()] end
local function SetPalette()
  for k, rgb in pairs(PALETTES[ThemeKey()]) do
    C[k] = C[k] or {}
    C[k][1], C[k][2], C[k][3] = rgb[1], rgb[2], rgb[3]
  end
end

local function L(key) return PSS:L(key) end
local function Show(widget, on) if on then widget:Show() else widget:Hide() end end
local function InCombat() return InCombatLockdown and InCombatLockdown() end

---------------------------------------------------------------------------
-- Themed primitives
---------------------------------------------------------------------------
local themed, panels, buttons = {}, {}, {}

local function Solid(parent, layer, color, alpha, sublevel)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
  t:SetTexture(WHITE)
  t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
  table.insert(themed, {kind="tex", obj=t, color=color, alpha=alpha or 1})
  return t
end

local function Border(parent, color, alpha, size)
  local edges = {}
  local function edge(p1, p2, horizontal)
    local t = Solid(parent, "BORDER", color, alpha or 1)
    t:SetPoint(p1, parent, p1, 0, 0)
    t:SetPoint(p2, parent, p2, 0, 0)
    if horizontal then t:SetHeight(size or 1) else t:SetWidth(size or 1) end
    table.insert(edges, t)
  end
  edge("TOPLEFT", "TOPRIGHT", true)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false)
  edge("TOPRIGHT", "BOTTOMRIGHT", false)
  return edges
end

local function SetEdgeColor(edges, rgb, alpha)
  for _, e in ipairs(edges or {}) do e:SetVertexColor(rgb[1], rgb[2], rgb[3], alpha or 1) end
end

-- Card / panel surface. In the textured theme it becomes leather with a metal rim.
local function ApplyPanel(item)
  local tex = Textured()
  if tex then
    item.fill:SetTexture(TEX .. "ClassicLeather")
    item.fill:SetVertexColor(1, 1, 1, 1)
  else
    item.fill:SetTexture(WHITE)
    local c = item.color
    item.fill:SetVertexColor(c[1], c[2], c[3], 1)
  end
  for _, e in ipairs(item.metal) do Show(e, tex) end
end

local function Panel(parent, color, noBorder)
  local item = {color = color or C.surface, metal = {}}
  item.fill = parent:CreateTexture(nil, "BACKGROUND")
  item.fill:SetAllPoints(parent)
  local function metal(a, b, horizontal)
    local e = parent:CreateTexture(nil, "BORDER", nil, 1)
    e:SetTexture(TEX .. "ClassicMetal")
    e:SetPoint(a, parent, a, 0, 0)
    e:SetPoint(b, parent, b, 0, 0)
    if horizontal then e:SetHeight(3) else e:SetWidth(3) end
    table.insert(item.metal, e)
  end
  metal("TOPLEFT", "TOPRIGHT", true)
  metal("BOTTOMLEFT", "BOTTOMRIGHT", true)
  metal("TOPLEFT", "BOTTOMLEFT", false)
  metal("TOPRIGHT", "BOTTOMRIGHT", false)
  table.insert(panels, item)
  ApplyPanel(item)
  if not noBorder then parent.pssEdges = Border(parent, C.border) end
  parent.pssPanel = item
  return item
end

local function Label(parent, text, size, color, width, justify, nowrap)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 13, "")
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  if nowrap and fs.SetWordWrap then fs:SetWordWrap(false) end
  fs:SetText(text or "")
  color = color or C.cream
  fs:SetTextColor(color[1], color[2], color[3])
  table.insert(themed, {kind="font", obj=fs, color=color})
  return fs
end

-- Buttons ----------------------------------------------------------------
local function StyleButton(b)
  local tex = Textured()
  local active = b.pssActive
  if not b.pssClassic then
    b.pssClassic = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.pssClassic:SetTexture(TEX .. "ClassicButton")
    b.pssClassic:SetAllPoints(b)
  end
  Show(b.pssClassic, tex)
  local flatAlpha = (tex or b.pssGhost) and 0 or 1
  b.pssFlat:SetAlpha(flatAlpha)
  local fill = active and not b.pssGhost and C.gold or C.surface
  b.pssFlat:SetVertexColor(fill[1], fill[2], fill[3], 1)
  for _, e in ipairs(b.pssBorders) do e:SetAlpha((tex or b.pssGhost) and 0 or 1) end
  b.pssGlow:SetAlpha((tex and active) and 0.35 or 0)
  if b.pssUnderline then Show(b.pssUnderline, active) end
  local fs = b:GetFontString()
  if fs then
    local c
    if tex then c = active and {1, 1, 1} or {1, 0.82, 0.15}
    elseif b.pssGhost then c = active and C.cream or C.muted
    elseif active then c = C.ink
    else c = C.cream end
    fs:SetTextColor(c[1], c[2], c[3])
  end
  b:SetAlpha(b.pssDisabled and 0.45 or 1)
end

local function SetActive(b, on)
  b.pssActive = on and true or false
  StyleButton(b)
end

local function MakeButton(parent, text, width, height, onClick, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 100, height or 30)
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, opts.size or 13, "")
  fs:SetPoint("CENTER", b, "CENTER", opts.textX or 0, 0)
  b:SetFontString(fs)
  b:SetText(text or "")
  b.pssFlat = Solid(b, "BACKGROUND", C.surface)
  b.pssFlat:SetAllPoints(b)
  b.pssBorders = Border(b, C.border)
  b.pssGlow = Solid(b, "ARTWORK", C.gold, 0)
  b.pssGlow:SetAllPoints(b)
  local hover = Solid(b, "HIGHLIGHT", C.gold, 0.14)
  hover:SetAllPoints(b)
  b.pssGhost = opts.ghost
  if opts.ghost then
    b.pssUnderline = Solid(b, "OVERLAY", C.gold, 1)
    b.pssUnderline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
    b.pssUnderline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
    b.pssUnderline:SetHeight(2)
  end
  if opts.icon then
    local icon = b:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(opts.icon)
    icon:SetSize(opts.iconSize or 18, opts.iconSize or 18)
    if opts.iconLeft then
      icon:SetPoint("LEFT", b, "LEFT", 10, 0)
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    else
      icon:SetPoint("CENTER")
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon
  end
  b:SetScript("OnClick", onClick)
  table.insert(buttons, b)
  StyleButton(b)
  return b
end

local function SetTip(widget, text)
  widget:SetScript("OnEnter", function(self)
    local t = type(text) == "function" and text(self) or text
    if not (t and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(PSS:Safe(t), 1, 0.87, 0.61, 1, true)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function IconButton(parent, texture, size, onClick, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local bg = Solid(b, "BACKGROUND", C.deep, 0.9)
  bg:SetAllPoints(b)
  b.pssEdges = Border(b, C.border)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(texture)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b.icon = icon
  local glow = Solid(b, "HIGHLIGHT", C.gold, 0.2)
  glow:SetAllPoints(b)
  b:SetScript("OnClick", onClick)
  if tip then SetTip(b, tip) end
  return b
end

-- Forward mouse-wheel input from list rows to their FauxScrollFrame.
local function ForwardWheel(widget, scroll, step)
  widget:EnableMouseWheel(true)
  widget:SetScript("OnMouseWheel", function(_, delta)
    local bar = scroll.ScrollBar or (scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"])
    if bar then bar:SetValue(bar:GetValue() - delta * step) end
  end)
end

local function SearchBox(parent, width, onChange)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(width, 32)
  Panel(box, C.surface)
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", box, "LEFT", 9, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetSize(width - 42, 26)
  edit:SetPoint("LEFT", box, "LEFT", 34, 0)
  edit:SetAutoFocus(false)
  edit:SetFont(FONT, 13, "")
  edit:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
  table.insert(themed, {kind="font", obj=edit, color=C.cream})
  edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
  box.hint = Label(box, "", 12, C.muted, width - 46, "LEFT", true)
  box.hint:SetPoint("LEFT", edit, "LEFT", 1, 0)
  edit:SetScript("OnTextChanged", function(e)
    Show(box.hint, (e:GetText() or "") == "")
    if onChange then onChange(e:GetText() or "") end
  end)
  box.edit = edit
  function box:Text() return string.lower(edit:GetText() or "") end
  return box
end

-- Progress bar on a StatusBar: it also accepts the client's secret values.
local function Bar(parent, width, height)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(width, height)
  local bg = Solid(bar, "BACKGROUND", C.dim)
  bg:SetAllPoints(bar)
  bar:SetStatusBarTexture(WHITE)
  function bar:Tint(rgb)
    rgb = rgb or C.gold
    self:SetStatusBarColor(rgb[1], rgb[2], rgb[3], 1)
  end
  function bar:SetFraction(fraction, rgb)
    self:SetMinMaxValues(0, 1)
    self:SetValue(math.max(0, math.min(1, fraction or 0)))
    self:Tint(rgb)
  end
  -- cur / max may be secret: hand them straight to the widget.
  function bar:SetRaw(cur, max, rgb)
    if not pcall(self.SetMinMaxValues, self, 0, max) or not pcall(self.SetValue, self, cur) then
      self:SetFraction(0, rgb)
      return
    end
    self:Tint(rgb)
  end
  bar:SetFraction(0)
  return bar
end

-- Rank pip: a small circle (filled = learned / taught, ring = next rank).
local function Dot(parent, size)
  local d = CreateFrame("Frame", nil, parent)
  d:SetSize(size, size)
  d.ring = d:CreateTexture(nil, "ARTWORK", nil, 1)
  d.ring:SetTexture(CIRCLE)
  d.ring:SetAllPoints(d)
  d.core = d:CreateTexture(nil, "ARTWORK", nil, 2)
  d.core:SetTexture(CIRCLE)
  d.core:SetPoint("CENTER", d, "CENTER", 0, 0)
  d.core:SetSize(size - 4, size - 4)
  return d
end
local function SetDot(d, state)
  local ring, core, alpha = C.muted, C.surface, 0.55
  if state == "have" then ring, core, alpha = C.gold, C.gold, 1
  elseif state == "faded" then ring, core, alpha = C.gold, C.gold, 0.4
  elseif state == "next" then ring, core, alpha = C.green, C.surface, 1 end
  d.ring:SetVertexColor(ring[1], ring[2], ring[3], alpha)
  d.core:SetVertexColor(core[1], core[2], core[3], alpha)
end

local function Badge(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(80, 18)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetTexture(WHITE)
  b.bg:SetAllPoints(b)
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(FONT, 10, "")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  function b:Set(kind, text)
    local s = STATUS[kind] or STATUS.none
    self.bg:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], 1)
    self.text:SetTextColor(s.fg[1], s.fg[2], s.fg[3])
    self.text:SetText(text or "")
    self:SetWidth(math.floor((self.text:GetStringWidth() or 60) + 16))
  end
  return b
end

---------------------------------------------------------------------------
-- Embedded 3D model (display ID first, then the creature ID with retries)
---------------------------------------------------------------------------
local function ModelHas(m)
  for _, method in ipairs({"GetModelFileID", "GetModel"}) do
    if type(m[method]) == "function" then
      local ok, v = pcall(m[method], m)
      if ok then return v ~= nil and v ~= "" and v ~= 0 end
    end
  end
  return nil
end
local function ModelTry(m)
  if m.unit and not m.triedUnit then
    m.triedUnit = true
    if pcall(m.SetUnit, m, m.unit) then return true end
  end
  if m.display and not m.triedDisplay then
    m.triedDisplay = true
    pcall(m.ClearModel, m)
    if pcall(m.SetDisplayInfo, m, m.display) then return true end
  end
  if m.npc and (m.tries or 0) < 4 then
    m.tries = (m.tries or 0) + 1
    if m.tries == 1 then pcall(m.ClearModel, m) end
    if pcall(m.SetCreature, m, m.npc) then return true end
  end
  return false
end
-- Pull the camera back: display models otherwise fill the whole well.
local function ModelFrame(m)
  pcall(m.SetPortraitZoom, m, 0)
  local scale = m.camScale or 1.7
  if m.zoomKey and PetSkillScoutDB and PetSkillScoutDB.modelZoom then
    scale = PetSkillScoutDB.modelZoom[m.zoomKey] or scale
  end
  if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, scale) end
end
local function ModelState(m, ok)
  if ok then ModelFrame(m) end
  m.pending = false
  if m.onState then m.onState(ok) end
end
local function ModelNext(m)
  local has = ModelHas(m)
  -- Clients that cannot report a model: keep a unit/display model.
  if has == nil and (m.triedUnit or m.triedDisplay) and (m.tries or 0) == 0 then has = true end
  if has then
    pcall(m.SetFacing, m, m.facing)
    ModelState(m, true)
  elseif not ModelTry(m) then
    pcall(m.ClearModel, m)
    ModelState(m, false)
  end
end

local allModels = {}
local function NewModel(parent)
  local m = CreateFrame("PlayerModel", nil, parent)
  table.insert(allModels, m)
  m.facing = math.rad(-25)
  m:EnableMouse(true)
  m:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition and GetCursorPosition() end)
  m:SetScript("OnMouseUp", function(self) self.dragX = nil end)
  m:SetScript("OnHide", function(self) self.dragX = nil end)
  m:SetScript("OnUpdate", function(self, elapsed)
    if self.dragX and GetCursorPosition then
      local x = GetCursorPosition()
      self.facing = self.facing + (x - self.dragX) * 0.02
      self.dragX = x
      pcall(self.SetFacing, self, self.facing)
    end
    if self.pending then
      self.wait = (self.wait or 0) + (elapsed or 0)
      if self.wait >= 0.6 then
        self.wait = 0
        ModelNext(self)
      end
    end
  end)
  -- opts = {unit=, display=, npc=}; the same subject is not reloaded.
  function m:ShowSubject(opts, force)
    opts = opts or {}
    local guid = opts.unit and UnitGUID and PSS.Plain(UnitGUID(opts.unit))
    local key = tostring(opts.unit) .. ":" .. tostring(guid) .. ":" .. tostring(opts.display) .. ":" .. tostring(opts.npc)
    if key == self.key and not force then return end
    self.key = key
    self.unit, self.display, self.npc = opts.unit, tonumber(opts.display), tonumber(opts.npc)
    self.triedUnit, self.triedDisplay, self.tries, self.wait = false, false, 0, 0
    self.facing = math.rad(-25)
    if not (self.unit or self.display or self.npc) then
      pcall(self.ClearModel, self)
      ModelState(self, false)
      return
    end
    if ModelTry(self) then
      self.pending = true
      ModelFrame(self)
      pcall(self.SetFacing, self, self.facing)
      if self.onState then self.onState(true) end
    else
      ModelState(self, false)
    end
  end
  return m
end

-- Viewport: dark well with a family icon shown while/if no model renders.
local function Viewport(parent, width, height, zoomKey)
  local v = CreateFrame("Frame", nil, parent)
  v:SetSize(width, height)
  local bg = Solid(v, "BACKGROUND", C.deep)
  bg:SetAllPoints(v)
  v.fallback = v:CreateTexture(nil, "ARTWORK")
  v.fallback:SetSize(math.min(64, height - 16), math.min(64, height - 16))
  v.fallback:SetPoint("CENTER", v, "CENTER", 0, 0)
  v.fallback:SetAlpha(0.35)
  v.fallback:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  v.model = NewModel(v)
  v.model:SetPoint("TOPLEFT", v, "TOPLEFT", 2, -2)
  v.model:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -2, 2)
  v.model.onState = function(ok) Show(v.fallback, not ok) end
  -- Wide, low wells (lists, tiles) need the camera further back than tall ones.
  v.model.camScale = (width / height > 2) and 2.0 or 1.7
  -- Large wells: mouse wheel zooms (saved per kind of view).
  if zoomKey then
    v.model.zoomKey = zoomKey
    v.model:EnableMouseWheel(true)
    v.model:SetScript("OnMouseWheel", function(m, delta)
      if not PetSkillScoutDB then return end
      PetSkillScoutDB.modelZoom = PetSkillScoutDB.modelZoom or {}
      local cur = PetSkillScoutDB.modelZoom[zoomKey] or m.camScale or 1.7
      cur = math.max(0.6, math.min(4.0, cur - delta * 0.15))
      PetSkillScoutDB.modelZoom[zoomKey] = cur
      if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, cur) end
    end)
  end
  v.badge = v:CreateTexture(nil, "OVERLAY")
  v.badge:SetSize(22, 22)
  v.badge:SetPoint("TOPLEFT", v, "TOPLEFT", 6, -6)
  v.badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  function v:SetSubject(opts, icon, force)
    self.fallback:SetTexture(icon)
    self.badge:SetTexture(icon)
    Show(self.badge, icon ~= nil)
    self.model:ShowSubject(opts, force)
  end
  return v
end

---------------------------------------------------------------------------
-- Shared helpers (family icons, taming notes, rank info)
---------------------------------------------------------------------------
local FAMILY_ICONS = {
  cat="Ability_Hunter_Pet_Cat", wolf="Ability_Hunter_Pet_Wolf",
  spider="Ability_Hunter_Pet_Spider", bear="Ability_Hunter_Pet_Bear",
  boar="Ability_Hunter_Pet_Boar", bat="Ability_Hunter_Pet_Bat",
  owl="Ability_Hunter_Pet_Owl", raptor="Ability_Hunter_Pet_Raptor",
  gorilla="Ability_Hunter_Pet_Gorilla", turtle="Ability_Hunter_Pet_Turtle",
  crocolisk="Ability_Hunter_Pet_Crocolisk", scorpion="Ability_Hunter_Pet_Scorpid",
  scorpid="Ability_Hunter_Pet_Scorpid", hyena="Ability_Hunter_Pet_Hyena",
  crab="Ability_Hunter_Pet_Crab", serpent="Ability_Hunter_Pet_WindSerpent",
  windserpent="Ability_Hunter_Pet_WindSerpent", cloudserpent="Ability_Hunter_Pet_WindSerpent",
  tallstrider="Ability_Hunter_Pet_TallStrider",
  carrionbird="Ability_Hunter_Pet_Vulture", vulture="Ability_Hunter_Pet_Vulture",
  birdofprey="Ability_Hunter_Pet_Owl", fox="Ability_Hunter_AspectOfTheFox",
}
local function FamilyIcon(family)
  local key = string.lower(tostring(family or "")):gsub("[^%a]", "")
  return "Interface\\Icons\\" .. (FAMILY_ICONS[key] or "Ability_Hunter_BeastCall")
end
PSS.FamilyIcon = FamilyIcon

local function LevelText(rec)
  if not rec or not rec.minLevel then return "?" end
  if rec.maxLevel and rec.maxLevel ~= rec.minLevel then return rec.minLevel .. "-" .. rec.maxLevel end
  return tostring(rec.minLevel)
end

-- Level-only taming guidance; actual tameability also depends on game rules.
local function TameLevelNote(beast)
  local level = tonumber(UnitLevel and UnitLevel("player")) or (PSS.player and tonumber(PSS.player.level))
  local low, high = tonumber(beast.minLevel), tonumber(beast.maxLevel)
  if not level or level < 1 or not low then return "|cffb7bbc4" .. L("tameUnknown") .. "|r" end
  high = high or low
  if level < low then return "|cffff7777" .. string.format(L("tameTooLow"), low) .. "|r"
  elseif level < high then return "|cffffd36a" .. L("tamePartial") .. "|r" end
  return "|cff7ee0a3" .. L("tameLevelOK") .. "|r"
end

-- "Rank 3: pet level 16 · 7 training points" plus how the skill is learned.
function PSS:RankInfoText(ability, rank)
  local parts = {}
  local meta = self.Ranks[ability] and tonumber(rank) and self.Ranks[ability][tonumber(rank)]
  if meta then
    local text = string.format(self:L("rankInfo"), tostring(rank), meta.petLevel or 0)
    if meta.tp and meta.tp > 0 then text = text .. "  ·  " .. string.format(self:L("rankTp"), meta.tp) end
    if meta.damage then text = text .. "  ·  " .. meta.damage end
    table.insert(parts, text)
  end
  local learn = self.Abilities[ability] and self.Abilities[ability].learn
  if learn == "family" then table.insert(parts, self:L("learnFamily"))
  elseif learn == "trainer" then table.insert(parts, self:L("learnTrainer")) end
  local effect = self.Abilities[ability] and self.Abilities[ability].effect
  if effect then table.insert(parts, self:L(effect)) end
  return table.concat(parts, "\n")
end

local function RanksForAbility(ability)
  local found = {}
  for rank in pairs(PSS.Ranks[ability] or {}) do found[tonumber(rank)] = true end
  for _, beast in ipairs(PSS.Beasts or {}) do
    if beast.ability == ability and tonumber(beast.rank) then found[tonumber(beast.rank)] = true end
  end
  local ranks = {}
  for rank in pairs(found) do table.insert(ranks, rank) end
  table.sort(ranks)
  return ranks
end
local function MaxRank(ability, atLeast)
  local m = atLeast or 1
  for _, r in ipairs(RanksForAbility(ability)) do if r > m then m = r end end
  return m
end

local function RankLabel(v)
  return L("rank") .. ": " .. ((v == "All" or v == nil) and L("all") or tostring(v))
end

-- Active pet knowledge: learned skill ranks and which skills its family can learn.
local function PetKnowledge()
  local pet = PSS.MyPet
  if not (pet and pet.active) then return nil end
  local known = {}
  for _, s in ipairs(pet.spells or {}) do
    if s.key then known[s.key] = math.max(known[s.key] or 0, s.rank or 0) end
  end
  local can = {}
  for _, key in ipairs((PSS.FamilySkills and PSS.FamilySkills[pet.family]) or {}) do can[key] = true end
  return known, can
end

-- Dropdown -----------------------------------------------------------------
-- `current` may be a getter so the check mark reflects the live value.
local function MakeDropdown(parent, values, current, width, callback, displayFn)
  local function Current() if type(current) == "function" then return current() end return current end
  local function Text(v) return displayFn and displayFn(v) or tostring(v) end
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, math.max(40, (width or 140) - 16))
  UIDropDownMenu_SetText(dd, Text(Current()))
  local field = Solid(dd, "ARTWORK", C.surfaceAlt, 1)
  field:SetPoint("TOPLEFT", dd, "TOPLEFT", 16, -3)
  field:SetSize(width or 140, 27)
  local arrow = Label(dd, "v", 13, C.gold, 20, "CENTER")
  arrow:SetPoint("RIGHT", field, "RIGHT", -5, 0)
  local valueText = dd.Text
  if not valueText then
    for _, region in ipairs({dd:GetRegions()}) do
      if region and region.GetObjectType and region:GetObjectType() == "FontString" and region ~= arrow then
        valueText = region
        break
      end
    end
  end
  if valueText then
    valueText:ClearAllPoints()
    valueText:SetPoint("LEFT", field, "LEFT", 10, 0)
    valueText:SetWidth(math.max(20, (width or 140) - 36))
    valueText:SetJustifyH("LEFT")
    if valueText.SetFont then valueText:SetFont(FONT, 12, "") end
  end
  -- The outline lives on a higher child frame so it is never hidden by panels.
  local outline = CreateFrame("Frame", nil, dd)
  outline:SetFrameLevel(dd:GetFrameLevel() + 5)
  outline:EnableMouse(false)
  outline:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
  outline:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", 0, 0)
  Border(outline, C.gold, 0.85)
  for _, region in ipairs({dd:GetRegions()}) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= field then
      region:SetAlpha(0)
    end
  end
  local menuButton = dd.Button
  if menuButton then
    menuButton:ClearAllPoints()
    menuButton:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
    menuButton:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", 0, 0)
    if menuButton.SetHitRectInsets then menuButton:SetHitRectInsets(0, 0, 0, 0) end
    for _, region in ipairs({menuButton:GetRegions()}) do
      if region and region.GetObjectType and region:GetObjectType() == "Texture" then region:SetAlpha(0) end
    end
  end
  UIDropDownMenu_Initialize(dd, function(self, level)
    local options = type(values) == "function" and values() or values
    for _, v in ipairs(options) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = Text(v)
      info.checked = v == Current()
      info.func = function()
        if type(current) ~= "function" then current = v end
        UIDropDownMenu_SetText(dd, Text(v))
        callback(v)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  function dd:Sync() UIDropDownMenu_SetText(self, Text(Current())) end
  return dd
end

---------------------------------------------------------------------------
-- Window, header and view switching
---------------------------------------------------------------------------
UI.views = {}
UI.view = "beasts"
UI.beastState = UI.beastState or {sort="near", family="All", skill="Any", rank="All"}
UI.rareState = UI.rareState or {mode="near"}
UI.routeState = UI.routeState or {}
UI.collectionState = UI.collectionState or {mode="looks", family="All", filter="all", scope="guild"}
UI.settingsSection = "general"

local function SavePosition()
  if not (frame and PetSkillScoutDB) then return end
  if PetSkillScoutDB.rememberPos == false then PetSkillScoutDB.framePos = nil return end
  local point, _, relPoint, x, y = frame:GetPoint(1)
  if point and x and y then PetSkillScoutDB.framePos = {point, relPoint, x, y} end
end

function UI:ApplyScale()
  if not frame then return end
  local s = tonumber(PetSkillScoutDB and PetSkillScoutDB.uiScale) or 1
  if s < 0.6 or s > 1.6 then s = 1 end
  frame:SetScale(s)
  self:PlaceFeedOverlay()
end

function UI:Create()
  if frame then return end
  SetPalette()
  frame = CreateFrame("Frame", "PetSkillScoutFrame", UIParent)
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f) f:StartMoving(); UI.moving = true end)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    UI.moving = false
    SavePosition()
    UI:PlaceFeedOverlay()
  end)
  frame:SetScript("OnUpdate", function()
    if UI.moving and UI.view == "pet" then UI:PlaceFeedOverlay() end
    -- Nearest-first list follows the player while the window is open.
    if UI.view == "beasts" and UI.beastState.sort == "near" and not UI.moving then
      local now = GetTime and GetTime() or 0
      if now - (UI.bDistAt or 0) > 4 then UI:UpdateBeastList(true) end
    end
  end)
  frame:SetScript("OnHide", function() UI.moving = false; UI:PlaceFeedOverlay() end)
  -- Models may be dropped while hidden: reload them on the next refresh.
  -- Author line at the bottom right; put back each time the window opens.
  local credit = frame:CreateFontString(nil, "OVERLAY")
  credit:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
  credit:SetTextColor(0.55, 0.55, 0.5)
  credit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 6)
  self.credit = credit
  local function Credit()
    credit:SetText(PSS:Credit())
    credit:SetAlpha(1)
    credit:Show()
  end
  Credit()
  frame:SetScript("OnShow", function()
    for _, m in ipairs(allModels) do m.key = nil end
    Credit()
  end)
  local pos = PetSkillScoutDB and PetSkillScoutDB.rememberPos ~= false and PetSkillScoutDB.framePos
  if type(pos) == "table" and pos[1] and tonumber(pos[3]) and tonumber(pos[4]) then
    frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3], pos[4])
  else
    frame:SetPoint("CENTER")
  end
  if UISpecialFrames then table.insert(UISpecialFrames, "PetSkillScoutFrame") end
  frame:Hide()

  local bg = Solid(frame, "BACKGROUND", C.background)
  bg:SetAllPoints(frame)
  self.frameEdges = Border(frame, C.gold, 0.8)
  -- Textured theme: stone backdrop and a heavy rim.
  self.stone = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  self.stone:SetTexture(TEX .. "ClassicStone")
  self.stone:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  self.stone:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
  self.rim = {}
  for _, def in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
    local t = frame:CreateTexture(nil, "BORDER", nil, 2)
    t:SetTexture(WHITE)
    t:SetVertexColor(0.46, 0.43, 0.38, 1)
    t:SetPoint(def[1], frame, def[1], 0, 0)
    t:SetPoint(def[2], frame, def[2], 0, 0)
    if def[3] then t:SetHeight(4) else t:SetWidth(4) end
    table.insert(self.rim, t)
  end

  -- Header ---------------------------------------------------------------
  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  header:SetHeight(HEADER)
  self.header = header
  self.headerFill = Solid(header, "BACKGROUND", C.surface)
  self.headerFill:SetAllPoints(header)
  self.headerArt = header:CreateTexture(nil, "BACKGROUND", nil, 1)
  self.headerArt:SetTexture(TEX .. "ClassicHeader")
  self.headerArt:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -4)
  self.headerArt:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 2)
  local line = Solid(header, "ARTWORK", C.gold, 0.45)
  line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  line:SetHeight(1)
  self.logo = header:CreateTexture(nil, "ARTWORK")
  self.logo:SetTexture(TEX .. "PetSkillScoutLogo")
  self.logo:SetSize(42, 42)
  self.logo:SetPoint("LEFT", header, "LEFT", 8, 0)
  -- The textured theme uses the protruding medallion on its own layer.
  self.crest = CreateFrame("Frame", nil, frame)
  self.crest:SetAllPoints(frame)
  self.crest:SetFrameLevel(frame:GetFrameLevel() + 30)
  self.medallion = self.crest:CreateTexture(nil, "OVERLAY")
  self.medallion:SetTexture(TEX .. "ClassicMedallion")
  self.medallion:SetSize(70, 70)
  self.medallion:SetPoint("TOPLEFT", frame, "TOPLEFT", -18, 14)
  self.title = Label(header, "PetSkillScout", 19, C.cream, 170, "LEFT", true)
  self.title:SetPoint("LEFT", header, "LEFT", 58, 1)
  if self.title.SetShadowOffset then self.title:SetShadowOffset(1, -1) end

  self.tabs = {}
  for i, def in ipairs({{"beasts", "tabBeasts"}, {"rares", "rarePets"}, {"pet", "myPet"}, {"route", "tabRoute"}, {"collection", "tabCollection"}, {"gear", "tabGear"}, {"quests", "tabQuests"}}) do
    local tab = MakeButton(header, "", 118, 44, function() UI:ShowView(def[1]) end, {ghost=true, size=14})
    tab:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 236 + (i - 1) * 122, 4)
    tab.view, tab.key = def[1], def[2]
    self.tabs[i] = tab
  end
  self.closeButton = MakeButton(header, "X", 34, 34, function() frame:Hide() end)
  self.closeButton:SetPoint("RIGHT", header, "RIGHT", -12, 0)
  self.gearButton = MakeButton(header, "", 34, 34, function()
    UI:ShowView(UI.view == "settings" and (UI.lastView or "beasts") or "settings")
  end, {icon="Interface\\Icons\\INV_Misc_Gear_01", iconSize=22})
  self.gearButton:SetPoint("RIGHT", self.closeButton, "LEFT", -8, 0)
  SetTip(self.gearButton, function() return L("settings") end)
  -- Network chip: hunters online, or a bright "Connect" when not connected.
  -- Joining a channel needs a secure click, so the chip opens the existing
  -- connect prompt right under itself (nothing protected lives in this window).
  self.netChip = CreateFrame("Button", nil, header)
  self.netChip:SetHeight(26)
  local netBg = Solid(self.netChip, "BACKGROUND", C.deep)
  netBg:SetAllPoints(self.netChip)
  self.netChip.edges = Border(self.netChip, C.border)
  self.netChip.dot = self.netChip:CreateTexture(nil, "ARTWORK")
  self.netChip.dot:SetTexture(WHITE)
  self.netChip.dot:SetSize(8, 8)
  self.netChip.dot:SetPoint("LEFT", self.netChip, "LEFT", 9, 0)
  self.netChip.text = Label(self.netChip, "", 11, C.cream, nil, "LEFT", true)
  self.netChip.text:SetPoint("LEFT", self.netChip.dot, "RIGHT", 6, 0)
  local netHl = Solid(self.netChip, "HIGHLIGHT", C.gold, 0.15)
  netHl:SetAllPoints(self.netChip)
  self.netChip:SetScript("OnClick", function(b)
    local N = PSS.Net
    if not N then return end
    UI:ShowView("network")
    if N:ChannelID() then return end
    if InCombatLockdown and InCombatLockdown() then
      PSS:Print(L("netChipCombat"))
    else
      N:ShowConnect(true, b)
      if C_Timer and C_Timer.After then C_Timer.After(4, function() UI:RefreshNetChip(); UI:Refresh() end) end
    end
  end)
  SetTip(self.netChip, function()
    local N = PSS.Net
    if not N then return "" end
    if N:ChannelID() then
      return string.format(L("netInfo"), N:OnlineCount(), L("netConnected")) .. "\n" .. L("netChipOnHint")
    end
    return L("netConnectTitle") .. "\n" .. L("netConnectSub")
  end)
  -- Character chip (click: refresh position / zone).
  self.chip = CreateFrame("Button", nil, header)
  self.chip:SetHeight(26)
  self.chip:SetPoint("RIGHT", self.gearButton, "LEFT", -10, 0)
  self.netChip:SetPoint("RIGHT", self.chip, "LEFT", -6, 0)
  local chipBg = Solid(self.chip, "BACKGROUND", C.deep)
  chipBg:SetAllPoints(self.chip)
  Border(self.chip, C.border)
  self.chipText = Label(self.chip, "", 11, C.muted, nil, "CENTER", true)
  self.chipText:SetPoint("CENTER", self.chip, "CENTER", 0, 0)
  self.chip:SetScript("OnClick", function() PSS:RefreshPlayer(); UI:Refresh() end)
  SetTip(self.chip, function() return L("refresh") end)

  -- Body -----------------------------------------------------------------
  self.body = CreateFrame("Frame", nil, frame)
  self.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(HEADER + 14))
  self.body:SetSize(BODY_W, BODY_H)

  self:BuildBeasts()
  self:BuildRares()
  self:BuildPet()
  self:BuildRoute()
  self:BuildCollection()
  self:BuildGear()
  self:BuildQuests()
  self:BuildNetwork()
  self:BuildSettings()
  self:ApplyScale()
  self:ApplyTheme()
  self:ShowView(self.view or "beasts")
end

function UI:ApplyTheme()
  SetPalette()
  for _, it in ipairs(themed) do
    local c = it.color
    if it.kind == "tex" then it.obj:SetVertexColor(c[1], c[2], c[3], it.alpha)
    else it.obj:SetTextColor(c[1], c[2], c[3]) end
  end
  for _, p in ipairs(panels) do ApplyPanel(p) end
  for _, b in ipairs(buttons) do StyleButton(b) end
  if frame then
    local tex = Textured()
    Show(self.stone, tex)
    for _, t in ipairs(self.rim) do Show(t, tex) end
    Show(self.headerArt, tex)
    self.headerFill:SetAlpha(tex and 0 or 1)
    Show(self.logo, not tex)
    Show(self.crest, tex)
    SetEdgeColor(self.frameEdges, C.gold, tex and 0 or 0.8)
  end
  if self.feedButton then self:StyleFeedOverlay() end
  if PSS.ModelPreview and PSS.ModelPreview.ApplyTheme then PSS.ModelPreview:ApplyTheme() end
  if PSS.Skin then PSS.Skin:Refresh() end
  if PSS.Layout then PSS.Layout:Apply() end
end

function UI:ShowView(name)
  if not frame then return end
  if name ~= "settings" then self.lastView = name end
  self.view = name
  self.petVisible = name == "pet"
  self.rareVisible = name == "rares"
  self.atlasVisible = false
  for key, panel in pairs(self.views) do Show(panel, key == name) end
  for _, tab in ipairs(self.tabs) do SetActive(tab, tab.view == name) end
  SetActive(self.gearButton, name == "settings")
  self:RefreshView()
  self:PlaceFeedOverlay()
end

-- Compatibility with older callers.
function UI:ShowPet(show) self:ShowView(show and "pet" or "beasts") end
function UI:ShowRare(show) self:ShowView(show and "rares" or "beasts") end
function UI:ShowAtlas(show) self:ShowView("beasts") end

function UI:RefreshHeader()
  -- Tabs sized to their text; the character chip gets the room that is left.
  -- Seven tabs in long languages do not fit at 14 pt: step the font down
  -- until they leave room for the chip (its right edge is at x = 1000).
  -- The network chip sits between the tabs and the character chip: keep its
  -- width out of the tabs' room too.
  local netW = self:RefreshNetChip() or 0
  local netRoom = netW > 0 and (netW + 6) or 0
  local TAB_RIGHT = 1000 - 10 - 150 - netRoom
  local widths, x
  for size = 14, 10, -1 do
    widths, x = {}, 204
    local pad, minW = size >= 13 and 22 or 14, size >= 13 and 80 or 56
    for i, tab in ipairs(self.tabs) do
      tab:SetText(L(tab.key))
      local fs = tab:GetFontString()
      if fs then fs:SetFont(FONT, size, "") end
      local w = math.max(minW, math.floor((fs and fs:GetStringWidth() or 80) + pad))
      widths[i] = w
      x = x + w + 2
    end
    if x <= TAB_RIGHT then break end
  end
  x = 204
  for i, tab in ipairs(self.tabs) do
    tab:SetWidth(widths[i])
    tab:ClearAllPoints()
    tab:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", x, 4)
    x = x + widths[i] + 2
  end
  PSS:RefreshPlayer()
  local p = PSS.player
  local where = p.zone or "?"
  if p.x and p.y then where = where .. string.format("  %.1f, %.1f", p.x * 100, p.y * 100) end
  local room = math.max(120, 1000 - x - 10 - 24 - netRoom)
  self.chipText:SetWidth(0)
  self.chipText:SetText(string.format("%s %d  ·  %s", L("level"), math.floor(p.level or 1), where))
  if (self.chipText:GetStringWidth() or 0) > room and p.zone then
    self.chipText:SetText(string.format("%s %d  ·  %s", L("level"), math.floor(p.level or 1), p.zone))
  end
  local width = math.min(room, math.floor(self.chipText:GetStringWidth() or 200))
  self.chipText:SetWidth(width)
  self.chip:SetWidth(width + 24)
end

-- Header network chip: green dot + online count, or a gold "Connect".
function UI:RefreshNetChip()
  local c = self.netChip
  if not c then return 0 end
  local N = PSS.Net
  local on = N and N:ChannelID()
  local enabled = not PetSkillScoutDB or PetSkillScoutDB.netEnabled ~= false
  if not N or not enabled then c:Hide(); return 0 end
  c:Show()
  c.text:SetWidth(0)
  if on then
    c.text:SetText(string.format(L("netChipOnline"), N:OnlineCount()))
    c.text:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
    c.dot:SetVertexColor(0.40, 0.87, 0.47, 1)
    SetEdgeColor(c.edges, self.view == "network" and C.gold or C.border)
  else
    c.text:SetText(L("netChipConnect"))
    c.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    c.dot:SetVertexColor(0.95, 0.40, 0.35, 1)
    SetEdgeColor(c.edges, C.gold)
  end
  local w = math.floor((c.text:GetStringWidth() or 60) + 32)
  c:SetWidth(w)
  return w
end

function UI:RefreshView()
  if not frame then return end
  self:RefreshHeader()
  if self.view == "beasts" then self:UpdateBeastList(true)
  elseif self.view == "rares" then self:UpdateRares(true)
  elseif self.view == "pet" then self:RefreshPet()
  elseif self.view == "route" then self:UpdateRoute()
  elseif self.view == "collection" then self:UpdateCollection()
  elseif self.view == "gear" then self:UpdateGear()
  elseif self.view == "quests" then self:UpdateQuests()
  elseif self.view == "network" then self:UpdateNetwork()
  elseif self.view == "settings" then self:RefreshSettings() end
end

function UI:Refresh()
  if not frame or not frame:IsShown() then return end
  self:RefreshView()
end

-- Language change: dropdown captions and every visible text.
function UI:Rebuild()
  if not frame then return end
  for _, dd in ipairs(self.dropdowns or {}) do dd:Sync() end
  self:RefreshView()
end

function UI:Toggle()
  self:Create()
  if frame:IsShown() then frame:Hide() else frame:Show(); self:RefreshView(); self:PlaceFeedOverlay() end
end

function UI:Open(view)
  self:Create()
  frame:Show()
  self:ShowView(view or self.view or "beasts")
end

---------------------------------------------------------------------------
-- Beasts: every tameable beast, filters, list + details
---------------------------------------------------------------------------
local BEAST_ROWS, BEAST_ROW_H, LIST_W = 10, 54, 458
local SORTS = {"near", "level", "speed", "name"}

function UI:BuildBeasts()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.beasts = p
  local st = self.beastState
  self.dropdowns = self.dropdowns or {}

  self.bSearch = SearchBox(p, 300, function() UI:UpdateBeastList(true) end)
  self.bSearch:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  self.bChips = {}
  for i, def in ipairs({{"fast", "chipFast"}, {"rare", "chipRare"}, {"teach", "chipTeach"}, {"mypet", "chipMyPet"}}) do
    local key = def[1]
    local chip = MakeButton(p, "", 120, 32, function(b)
      st[key] = not st[key]
      SetActive(b, st[key])
      UI:UpdateBeastList(true)
    end, {size=12})
    chip:SetPoint("TOPLEFT", p, "TOPLEFT", 312 + (i - 1) * 126, 0)
    chip.state, chip.key = key, def[2]
    self.bChips[i] = chip
  end
  self.bSort = MakeButton(p, "", 190, 32, function()
    for i, m in ipairs(SORTS) do if m == st.sort then st.sort = SORTS[i % #SORTS + 1] break end end
    UI:UpdateBeastList(true)
  end, {size=12})
  self.bSort:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)

  local families = {"All"}
  for _, f in ipairs(PSS.Families) do table.insert(families, f) end
  self.bFamilyDD = MakeDropdown(p, families, function() return st.family end, 196,
    function(v) st.family = v; UI:UpdateBeastList(true) end,
    function(v) return L("family") .. ": " .. (v == "All" and L("all") or PSS:NameFamily(v)) end)
  self.bFamilyDD:SetPoint("TOPLEFT", p, "TOPLEFT", -16, -40)
  local skills = {"Any"}
  local keys = {}
  for k in pairs(PSS.Abilities) do table.insert(keys, k) end
  table.sort(keys)
  for _, k in ipairs(keys) do table.insert(skills, k) end
  self.bSkillDD = MakeDropdown(p, skills, function() return st.skill end, 210,
    function(v) st.skill = v; st.rank = "All"; UI.bRankDD:Sync(); UI:UpdateBeastList(true) end,
    function(v) return L("skill") .. ": " .. (v == "Any" and L("anySkill") or PSS:NameAbility(v)) end)
  self.bSkillDD:SetPoint("TOPLEFT", p, "TOPLEFT", 190, -40)
  self.bRankDD = MakeDropdown(p, function()
      local list = RanksForAbility(st.skill)
      table.insert(list, 1, "All")
      return list
    end, function() return st.rank end, 120,
    function(v) st.rank = v; UI:UpdateBeastList(true) end, RankLabel)
  self.bRankDD:SetPoint("TOPLEFT", p, "TOPLEFT", 410, -40)
  table.insert(self.dropdowns, self.bFamilyDD)
  table.insert(self.dropdowns, self.bSkillDD)
  table.insert(self.dropdowns, self.bRankDD)
  self.bInfo = Label(p, "", 11, C.muted, 330, "LEFT", true)
  self.bInfo:SetPoint("TOPLEFT", p, "TOPLEFT", 556, -49)
  self.bCount = Label(p, "", 12, C.muted, 170, "RIGHT", true)
  self.bCount:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -49)

  -- List
  self.bScroll = CreateFrame("ScrollFrame", "PetSkillScoutBeastScroll", p, "FauxScrollFrameTemplate")
  self.bScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84)
  self.bScroll:SetSize(LIST_W, BEAST_ROWS * BEAST_ROW_H)
  self.bScroll:SetScript("OnVerticalScroll", function(f, offset)
    FauxScrollFrame_OnVerticalScroll(f, offset, BEAST_ROW_H, function() UI:UpdateBeastList() end)
  end)
  self.bRows = {}
  for i = 1, BEAST_ROWS do
    local row = CreateFrame("Button", nil, p)
    row:SetSize(LIST_W, BEAST_ROW_H - 6)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84 - (i - 1) * BEAST_ROW_H)
    Panel(row, C.surface)
    row.sel = Solid(row, "ARTWORK", C.gold, 0.12)
    row.sel:SetAllPoints(row)
    row.bar = Solid(row, "OVERLAY", C.gold, 1)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    local hover = Solid(row, "HIGHLIGHT", C.gold, 0.08)
    hover:SetAllPoints(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = Label(row, "", 14, C.cream, 290, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -7)
    row.sub = Label(row, "", 11, C.muted, 300, "LEFT", true)
    row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -27)
    row.speed = Label(row, "", 12, C.cream, 90, "RIGHT", true)
    row.speed:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
    row.tags = Label(row, "", 10, C.muted, 110, "RIGHT", true)
    row.tags:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 8)
    row:SetScript("OnClick", function(r)
      if r.rec then UI.bSelected = r.rec.npcID; UI:UpdateBeastList() end
    end)
    ForwardWheel(row, self.bScroll, BEAST_ROW_H)
    self.bRows[i] = row
  end
  self.bEmpty = Label(p, "", 12, C.muted, LIST_W - 20)
  self.bEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -96)

  self:BuildBeastDetail(p)
end

function UI:BuildBeastDetail(p)
  local d = CreateFrame("Frame", nil, p)
  d:SetPoint("TOPLEFT", p, "TOPLEFT", 492, -84)
  d:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  Panel(d, C.surface)
  self.detail = d
  local w = BODY_W - 492 - 28
  d.view = Viewport(d, w, 210, "detail")
  d.view:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -14)
  d.dragHint = Label(d.view, "", 10, C.muted, 200, "RIGHT", true)
  d.dragHint:SetPoint("BOTTOMRIGHT", d.view, "BOTTOMRIGHT", -8, 6)
  d.name = Label(d, "", 22, C.cream, w - 120, "LEFT", true)
  d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -236)
  d.badges = {}
  for i = 1, 4 do
    d.badges[i] = Badge(d)
    d.badges[i]:Hide()
  end
  d.stats = {}
  local boxW = math.floor((w - 3 * 8) / 4)
  for i = 1, 4 do
    local box = CreateFrame("Frame", nil, d)
    box:SetSize(boxW, 50)
    box:SetPoint("TOPLEFT", d, "TOPLEFT", 14 + (i - 1) * (boxW + 8), -292)
    local bg = Solid(box, "BACKGROUND", C.deep, 0.8)
    bg:SetAllPoints(box)
    box.key = Label(box, "", 10, C.muted, boxW - 16, "LEFT", true)
    box.key:SetPoint("TOPLEFT", box, "TOPLEFT", 9, -8)
    box.value = Label(box, "", 13, C.cream, boxW - 16, "LEFT", true)
    box.value:SetPoint("TOPLEFT", box, "TOPLEFT", 9, -26)
    d.stats[i] = box
  end
  -- Teaches box
  local teach = CreateFrame("Frame", nil, d)
  teach:SetSize(w, 92)
  teach:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -352)
  local tbg = Solid(teach, "BACKGROUND", C.deep, 0.8)
  tbg:SetAllPoints(teach)
  teach.edges = Border(teach, C.gold, 0.35)
  teach.title = Label(teach, "", 10, C.muted, 200, "LEFT", true)
  teach.title:SetPoint("TOPLEFT", teach, "TOPLEFT", 10, -8)
  teach.lines = {}
  for i = 1, 2 do
    local line = {}
    line.name = Label(teach, "", 13, C.cream, 150, "LEFT", true)
    line.name:SetPoint("TOPLEFT", teach, "TOPLEFT", 10, -28 - (i - 1) * 28)
    line.dots = {}
    for j = 1, 10 do
      local dot = Dot(teach, 11)
      dot:SetPoint("TOPLEFT", teach, "TOPLEFT", 166 + (j - 1) * 14, -31 - (i - 1) * 28)
      line.dots[j] = dot
    end
    line.status = Label(teach, "", 11, C.muted, w - 318, "RIGHT", true)
    line.status:SetPoint("TOPRIGHT", teach, "TOPRIGHT", -10, -29 - (i - 1) * 28)
    teach.lines[i] = line
  end
  teach.none = Label(teach, "", 12, C.muted, w - 20)
  teach.none:SetPoint("TOPLEFT", teach, "TOPLEFT", 10, -30)
  d.teach = teach
  d.tame = Label(d, "", 12, C.muted, w, "LEFT")
  d.tame:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -456)
  d.zones = Label(d, "", 11, C.muted, w, "LEFT")
  d.zones:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -478)
  -- Actions
  d.arrow = MakeButton(d, "", 164, 34, function()
    if UI.bRec and PSS.Nav then PSS.Nav:SetTarget(PSS.Nav:TargetFromAtlas(UI.bRec.npcID) or PSS.Nav:TargetFromBeast(UI.bRec)) end
  end, {icon="Interface\\Minimap\\MinimapArrow", iconSize=18, iconLeft=true})
  d.arrow:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 14)
  d.map = MakeButton(d, "", 130, 34, function() if UI.bRec and PSS.Map then PSS.Map:Show(UI.bRec) end end)
  d.map:SetPoint("LEFT", d.arrow, "RIGHT", 8, 0)
  d.model = MakeButton(d, "", 110, 34, function() if UI.bRec and PSS.ModelPreview then PSS.ModelPreview:Show(UI.bRec) end end)
  d.model:SetPoint("LEFT", d.map, "RIGHT", 8, 0)
  d.track = MakeButton(d, "", 120, 34, function(b)
    if not UI.bRec then return end
    PSS:SetTracked(UI.bRec, not PSS:IsTracked(UI.bRec))
    if PSS.Minimap then PSS.Minimap:Refresh() end
    SetActive(b, PSS:IsTracked(UI.bRec))
  end)
  d.track:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 14)
  d.empty = Label(d, "", 13, C.muted, w, "CENTER")
  d.empty:SetPoint("CENTER", d, "CENTER", 0, 0)
end

local function BeastMatches(rec, st, query, petKnown, petCan)
  if st.family ~= "All" and rec.family ~= st.family then return false end
  if st.fast and not rec.fast then return false end
  if st.rare and not rec.isRare then return false end
  if st.teach and not rec.teaches then return false end
  if st.skill ~= "Any" or st.mypet then
    local ok = false
    for _, t in ipairs(rec.teaches or {}) do
      local good = true
      if st.skill ~= "Any" then
        good = t.ability == st.skill and (st.rank == "All" or tonumber(t.rank) == tonumber(st.rank))
      end
      if good and st.mypet then
        good = petCan ~= nil and petCan[t.ability] and (tonumber(t.rank) or 0) > (petKnown[t.ability] or 0)
      end
      if good then ok = true break end
    end
    if not ok then return false end
  end
  if query ~= "" then
    local hay = string.lower(rec.name .. " " .. table.concat(rec.zones or {}, " ") .. " " .. (rec.family or "") ..
      " " .. (rec.family and PSS:NameFamily(rec.family) or ""))
    if not string.find(hay, query, 1, true) then return false end
  end
  return true
end

function UI:UpdateBeastList(rebuild)
  if not self.bRows then return end
  local st = self.beastState
  local A = PSS.Atlas
  if rebuild or not self.bMatches then
    A:Build()
    if st.mypet and PSS.MyPet then PSS.MyPet:Scan() end
    local petKnown, petCan = PetKnowledge()
    local query = self.bSearch:Text()
    local list = {}
    for _, rec in ipairs(A.list) do
      if BeastMatches(rec, st, query, petKnown or {}, petCan) then table.insert(list, rec) end
    end
    -- Distance from the player to the closest spawn point of each beast.
    local here = PSS.Nav and { PSS.Nav:PlayerPos() } or {}
    for _, rec in ipairs(list) do
      rec._dist, rec._other = nil, nil
      if here[1] and rec.mapID and rec.spawnPoints and #rec.spawnPoints > 0 then
        if rec.mapID == here[1] then
          local _, _, d = PSS.Nav:Nearest({points = rec.spawnPoints}, here[1], here[2], here[3])
          rec._dist = d
        else
          local p = rec.spawnPoints[1]
          rec._dist, rec._other = PSS.Nav:DistanceTo(rec.mapID, p[1], p[2], here)
        end
      end
    end
    self.bDistAt = GetTime and GetTime() or 0
    table.sort(list, function(a, b)
      if st.sort == "near" then
        local ka = a._dist and 0 or (a._other and 1 or 2)
        local kb = b._dist and 0 or (b._other and 1 or 2)
        if ka ~= kb then return ka < kb end
        if a._dist and b._dist and a._dist ~= b._dist then return a._dist < b._dist end
      end
      if st.sort == "speed" and a.speed ~= b.speed then return a.speed < b.speed end
      if st.sort == "name" and a.name ~= b.name then return a.name < b.name end
      local la, lb = a.minLevel or 99, b.minLevel or 99
      if la ~= lb then return la < lb end
      return a.name < b.name
    end)
    self.bMatches = list
    local found = false
    for _, rec in ipairs(list) do if rec.npcID == self.bSelected then found = true break end end
    if not found then self.bSelected = list[1] and list[1].npcID end
  end
  local list = self.bMatches
  -- Static texts (language may have changed).
  self.bSearch.hint:SetText(L("searchBeasts"))
  for _, chip in ipairs(self.bChips) do
    chip:SetText(L(chip.key))
    SetActive(chip, st[chip.state])
  end
  self.bSort:SetText(string.format(L("atlasSort"), L("sort_" .. st.sort)))
  Show(self.bRankDD, st.skill ~= "Any")
  local info = ""
  if st.skill ~= "Any" then
    info = PSS:RankInfoText(st.skill, st.rank ~= "All" and st.rank or nil)
    info = info:match("^[^\n]*") or ""
  end
  self.bInfo:SetText(info)
  self.bCount:SetText(string.format(L("atlasCount"), #list, #A.list))
  -- Empty state
  if #list == 0 then
    local text = L("noMatches")
    if st.mypet and not (PSS.MyPet and PSS.MyPet.active) then text = L("petSummonFilter")
    elseif st.skill ~= "Any" then
      local learn = PSS.Abilities[st.skill] and PSS.Abilities[st.skill].learn
      local more = PSS:RankInfoText(st.skill, nil)
      text = (learn == "beast" or learn == nil) and L("learnNoBeasts") or more
    end
    self.bEmpty:SetText(text)
    self.bEmpty:Show()
  else
    self.bEmpty:Hide()
  end
  FauxScrollFrame_Update(self.bScroll, #list, BEAST_ROWS, BEAST_ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.bScroll)
  for i, row in ipairs(self.bRows) do
    local rec = list[i + offset]
    row.rec = rec
    if rec then
      local selected = rec.npcID == self.bSelected
      Show(row.sel, selected)
      Show(row.bar, selected)
      row.icon:SetTexture(FamilyIcon(rec.family))
      row.name:SetText(rec.name)
      local zone = rec.zones and rec.zones[1] or L("atlasNoZone")
      local sub = (rec.family and PSS:NameFamily(rec.family) or "?") .. "  ·  " .. L("level") .. " " .. LevelText(rec) .. "  ·  " .. zone
      if rec._dist then sub = sub .. "  ·  |cff8fe0a0" .. PSS.Nav:DistanceText(rec._dist) .. "|r"
      elseif rec._other then sub = sub .. "  ·  " .. L("routeOtherContinent") end
      row.sub:SetText(sub)
      row.speed:SetText(string.format("%.1f", rec.speed or 2) .. "s")
      local c = rec.fast and C.green or (rec.speed and rec.speed > 2 and C.red or C.cream)
      row.speed:SetTextColor(c[1], c[2], c[3])
      local tags = {}
      if rec.isRare then table.insert(tags, "|cffb592f5" .. L("tagRare") .. "|r") end
      if rec.elite then table.insert(tags, "|cffff8040" .. L("rareElite") .. "|r") end
      if rec.teaches then table.insert(tags, "|cff8fc8ff" .. L("tagTeaches") .. "|r") end
      row.tags:SetText(table.concat(tags, " · "))
      row:Show()
    else
      row:Hide()
    end
  end
  self:ShowBeastDetail(PSS.Atlas:Get(self.bSelected))
end

function UI:ShowBeastDetail(rec)
  local d = self.detail
  self.bRec = rec
  local hasRec = rec ~= nil
  for _, child in ipairs({d.view, d.name, d.teach, d.tame, d.zones, d.arrow, d.map, d.model, d.track}) do Show(child, hasRec) end
  for _, box in ipairs(d.stats) do Show(box, hasRec) end
  d.empty:SetText(L("selectBeast"))
  Show(d.empty, not hasRec)
  for _, b in ipairs(d.badges) do b:Hide() end
  if not rec then return end
  d.view:SetSubject({display=rec.displayID, npc=rec.npcID}, FamilyIcon(rec.family))
  d.dragHint:SetText(L("modelDrag"))
  d.name:SetText(rec.name)
  -- Badges right of the name
  local badges = {}
  if rec.isRare then table.insert(badges, {"want", L("tagRare")}) end
  if rec.elite then table.insert(badges, {"none", L("rareElite")}) end
  if rec.new then table.insert(badges, {"new", L("rareNew")}) end
  if rec.fast then table.insert(badges, {"tamed", L("ttFast")}) end
  local anchor
  for i, def in ipairs(badges) do
    local b = d.badges[i]
    if not b then break end
    b:Set(def[1], def[2])
    b:ClearAllPoints()
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    else b:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -266) end
    b:Show()
    anchor = b
  end
  local stats = {
    {L("statLevel"), LevelText(rec)},
    {L("statAttack"), string.format("%.1f s", rec.speed or 2)},
    {L("statZone"), rec.zone or L("atlasNoZone")},
    {L("statSpawns"), rec.spawnPoints and tostring(#rec.spawnPoints) or "—"},
  }
  for i, box in ipairs(d.stats) do
    box.key:SetText(stats[i][1])
    box.value:SetText(stats[i][2])
  end
  local sc = rec.fast and C.green or C.cream
  d.stats[2].value:SetTextColor(sc[1], sc[2], sc[3])
  -- Teaches + comparison with the active pet
  local t = d.teach
  t.title:SetText(L("teachesHeader"))
  local list, seen = {}, {}
  for _, item in ipairs(rec.teaches or {}) do
    local key = item.ability .. ":" .. tostring(item.rank)
    if not seen[key] then seen[key] = true table.insert(list, item) end
  end
  local petKnown, petCan = PetKnowledge()
  for i, line in ipairs(t.lines) do
    local item = list[i]
    local on = item ~= nil
    Show(line.name, on)
    Show(line.status, on)
    for _, dot in ipairs(line.dots) do dot:Hide() end
    if item then
      local rank = tonumber(item.rank) or 0
      line.name:SetText(string.format(L("teachLine"), PSS:NameAbility(item.ability), tostring(item.rank or "?")))
      local maxRank = math.min(10, MaxRank(item.ability, rank))
      for j = 1, maxRank do
        local dot = line.dots[j]
        SetDot(dot, j == rank and "have" or (j < rank and "faded" or "none"))
        dot:Show()
      end
      local meta = PSS.Ranks[item.ability] and PSS.Ranks[item.ability][rank]
      local status = meta and meta.petLevel and string.format(L("teachPetLevel"), meta.petLevel) or ""
      local col = C.muted
      if petCan then
        local s
        if not petCan[item.ability] then s, col = L("teachCant"), C.muted
        elseif (petKnown[item.ability] or 0) >= rank then s, col = L("teachKnown"), C.muted
        else s, col = L("teachNew"), C.green end
        status = status ~= "" and (status .. "  ·  " .. s) or s
      end
      line.status:SetText(status)
      line.status:SetTextColor(col[1], col[2], col[3])
    end
  end
  t.none:SetText(L("teachesNone"))
  Show(t.none, #list == 0)
  t:SetHeight(#list > 1 and 92 or 64)
  d.tame:SetText(TameLevelNote(rec) .. (rec.isRare and ("   |cffb592f5" .. L("rareCreature") .. "|r") or ""))
  d.tame:ClearAllPoints()
  d.tame:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
  d.zones:ClearAllPoints()
  d.zones:SetPoint("TOPLEFT", d.tame, "BOTTOMLEFT", 0, -8)
  d.zones:SetText(#(rec.zones or {}) > 1 and (L("allZones") .. ": " .. table.concat(rec.zones, ", ")) or "")
  d.arrow:SetText(L("btnArrow"))
  d.map:SetText(L("btnMap"))
  d.model:SetText(L("btn3D"))
  local canNav = rec.mapID ~= nil
  d.arrow.pssDisabled, d.map.pssDisabled = not canNav, not canNav
  d.arrow:EnableMouse(canNav)
  d.map:EnableMouse(canNav)
  StyleButton(d.arrow)
  StyleButton(d.map)
  local tracked = PSS:IsTracked(rec)
  d.track:SetText(tracked and L("btnTracked") or L("btnTrack"))
  SetActive(d.track, tracked)
end

-- From My Pet: show beasts teaching the given skill/rank.
local function SearchFor(ability, rank)
  local st = UI.beastState
  st.skill, st.rank, st.family = ability, rank or "All", "All"
  st.mypet, st.fast, st.rare, st.teach = false, false, false, false
  UI.bSearch.edit:SetText("")
  for _, dd in ipairs(UI.dropdowns) do dd:Sync() end
  UI.bSelected = nil
  UI:ShowView("beasts")
end
UI.SearchFor = SearchFor

---------------------------------------------------------------------------
-- Rare pets: collection header + tile grid
---------------------------------------------------------------------------
local TILE_COLS, TILE_ROWS, TILE_W, TILE_H, TILE_GAP = 4, 2, 255, 268, 10
local DIRS = {"dirE", "dirNE", "dirN", "dirNW", "dirW", "dirSW", "dirS", "dirSE"}

local function Direction(dx, dy)
  -- dx: yards east, dy: yards south.
  local angle = math.deg(math.atan2(-dy, dx))
  if angle < 0 then angle = angle + 360 end
  local index = math.floor((angle + 22.5) / 45) % 8 + 1
  return L(DIRS[index])
end

function UI:BuildRares()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.rares = p
  -- Collection header
  local ring = CreateFrame("Frame", nil, p)
  ring:SetSize(70, 70)
  ring:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  local ringBg = ring:CreateTexture(nil, "BACKGROUND")
  ringBg:SetTexture(CIRCLE)
  ringBg:SetAllPoints(ring)
  table.insert(themed, {kind="tex", obj=ringBg, color=C.dim, alpha=1})
  ringBg:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1)
  local ringIn = ring:CreateTexture(nil, "BORDER")
  ringIn:SetTexture(CIRCLE)
  ringIn:SetSize(58, 58)
  ringIn:SetPoint("CENTER")
  table.insert(themed, {kind="tex", obj=ringIn, color=C.background, alpha=1})
  ringIn:SetVertexColor(C.background[1], C.background[2], C.background[3], 1)
  self.rPercent = Label(ring, "", 16, C.gold, 70, "CENTER", true)
  self.rPercent:SetPoint("CENTER", ring, "CENTER", 0, 0)
  self.rTitle = Label(p, "", 20, C.cream, 270, "LEFT", true)
  self.rTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 86, -6)
  self.rSub = Label(p, "", 12, C.muted, 270, "LEFT", true)
  self.rSub:SetPoint("TOPLEFT", p, "TOPLEFT", 86, -34)
  self.rBar = Bar(p, 270, 6)
  self.rBar:SetPoint("TOPLEFT", p, "TOPLEFT", 86, -56)
  self.rModes = {}
  for i, mode in ipairs({"near", "timer", "zone", "level"}) do
    local b = MakeButton(p, "", 104, 32, function()
      UI.rareState.mode = mode
      FauxScrollFrame_SetOffset(UI.rScroll, 0)
      local bar = UI.rScroll.ScrollBar or _G["PetSkillScoutRareGridScrollBar"]
      if bar then bar:SetValue(0) end
      UI:UpdateRares(true)
    end)
    b:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(4 - i) * 110, -8)
    b.mode = mode
    self.rModes[i] = b
  end
  self.rSearch = SearchBox(p, 250, function() UI:UpdateRares(true) end)
  self.rSearch:SetPoint("TOPRIGHT", p, "TOPRIGHT", -450, -8)

  -- Grid
  self.rScroll = CreateFrame("ScrollFrame", "PetSkillScoutRareGrid", p, "FauxScrollFrameTemplate")
  self.rScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -82)
  self.rScroll:SetSize(TILE_COLS * (TILE_W + TILE_GAP) - TILE_GAP, TILE_ROWS * (TILE_H + TILE_GAP))
  self.rScroll:SetScript("OnVerticalScroll", function(f, offset)
    FauxScrollFrame_OnVerticalScroll(f, offset, TILE_H + TILE_GAP, function() UI:UpdateRares() end)
  end)
  self.rTiles = {}
  local R = PSS.RarePets
  for row = 1, TILE_ROWS do
    for col = 1, TILE_COLS do
      local tile = CreateFrame("Frame", nil, p)
      tile:SetSize(TILE_W, TILE_H)
      tile:SetPoint("TOPLEFT", p, "TOPLEFT", (col - 1) * (TILE_W + TILE_GAP), -82 - (row - 1) * (TILE_H + TILE_GAP))
      Panel(tile, C.surface)
      tile.view = Viewport(tile, TILE_W - 16, 112)
      tile.view:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -8)
      tile.name = Label(tile, "", 14, C.cream, TILE_W - 80, "LEFT", true)
      tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -128)
      tile.level = Label(tile, "", 11, C.muted, 64, "RIGHT", true)
      tile.level:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -10, -131)
      tile.meta = Label(tile, "", 11, C.muted, TILE_W - 20, "LEFT", true)
      tile.meta:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -150)
      tile.badge = Badge(tile)
      tile.badge:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -170)
      tile.speed = Label(tile, "", 11, C.muted, 110, "RIGHT", true)
      tile.speed:SetPoint("RIGHT", tile, "RIGHT", -10, 0)
      tile.speed:SetPoint("TOP", tile.badge, "TOP", 0, -3)
      tile.extra = Badge(tile)
      tile.extra:SetPoint("LEFT", tile.badge, "RIGHT", 6, 0)
      tile.seen = Label(tile, "", 10, C.muted, TILE_W - 20, "LEFT", true)
      tile.seen:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -196)
      tile.timer = Label(tile, "", 10, C.muted, TILE_W - 20, "LEFT", true)
      tile.timer:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -212)
      local function act(fn) return function() if tile.entry then fn(tile.entry) end end end
      local function changed() UI:UpdateRares(); if PSS.RareMap then PSS.RareMap:Refresh() end end
      tile.want = IconButton(tile, TEX .. "Rare_wanted", 28, act(function(e) R:SetWanted(e, not R:IsWanted(e)); changed() end),
        function() return L("rareWant") end)
      tile.tamed = IconButton(tile, TEX .. "Rare_tamed", 28, act(function(e) R:SetCollected(e, not R:IsCollected(e)); changed() end),
        function() return L("rareTamed") end)
      tile.map = IconButton(tile, TEX .. "Rare_map", 28, act(function(e) if PSS.RareMap then PSS.RareMap:Focus(e) end end),
        function() return L("map") end)
      tile.arrow = IconButton(tile, "Interface\\Minimap\\MinimapArrow", 28,
        act(function(e) if PSS.Nav then PSS.Nav:SetTarget(PSS.Nav:TargetFromBeast(e.beast)) end end),
        function() return L("arrowButton") end)
      tile.model = IconButton(tile, TEX .. "Rare_model", 28, act(function(e) if PSS.ModelPreview then PSS.ModelPreview:Show(e.beast) end end),
        function() return L("model") end)
      for i, b in ipairs({tile.want, tile.tamed, tile.map, tile.arrow, tile.model}) do
        b:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 10 + (i - 1) * 34, 10)
      end
      ForwardWheel(tile, self.rScroll, TILE_H + TILE_GAP)
      -- Hover: full sighting and respawn details.
      tile:EnableMouse(true)
      SetTip(tile, function()
        local e = tile.entry
        if not e then return nil end
        local lines = {e.name}
        local seen = tile.seen:GetText()
        if seen and seen ~= "" then table.insert(lines, seen) end
        local full = PSS.RareTimer and PSS.RareTimer:Text(e)
        if full then table.insert(lines, full) end
        local lo, hi, n = PSS.RareTimer and PSS.RareTimer:Window(e)
        if lo then table.insert(lines, string.format(L("timerHistory"), PSS.RareTimer:Duration(lo) ..
          (hi - lo >= 300 and (" - " .. PSS.RareTimer:Duration(hi)) or ""), n)) end
        return table.concat(lines, "\n")
      end)
      table.insert(self.rTiles, tile)
    end
  end
  self.rEmpty = Label(p, "", 13, C.muted, 600, "LEFT")
  self.rEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -100)
end

function UI:UpdateRares(rebuild)
  if not self.rTiles then return end
  local R = PSS.RarePets
  if not R then return end
  if rebuild or not self.rMatches then
    if PSS.zoneMapsChanged or not R.entries or #R.entries == 0 then
      PSS.zoneMapsChanged = false
      R:Build()
    end
    local mapID, px, py
    if PSS.Nav then mapID, px, py = PSS.Nav:PlayerPos() end
    local exact = mapID and PSS.Nav:MapSize(mapID) ~= nil
    local query = self.rSearch:Text()
    local list = {}
    for _, e in ipairs(R.entries or {}) do
      e.dist, e.dir = nil, nil
      if mapID and e.beast.mapID == mapID then
        local t = PSS.Nav:TargetFromBeast(e.beast)
        if t then
          local dx, dy, dist = PSS.Nav:Nearest(t, mapID, px, py)
          if dist then e.dist, e.dir, e.approx = dist, Direction(dx, dy), not exact end
        end
      end
      local hay = string.lower((e.name or "") .. " " .. (e.zone or "") .. " " .. (e.family or "") .. " " ..
        (e.family and PSS:NameFamily(e.family) or ""))
      if query == "" or string.find(hay, query, 1, true) then table.insert(list, e) end
    end
    local mode = self.rareState.mode
    local T = PSS.RareTimer
    if mode == "timer" and T then
      for _, e in ipairs(list) do
        e.remaining = T:Remaining(e)
        if not e.remaining and T:Elapsed(e) then e.remaining = 1e8 end
      end
    end
    table.sort(list, function(a, b)
      if mode == "timer" then
        if (a.remaining ~= nil) ~= (b.remaining ~= nil) then return a.remaining ~= nil end
        if a.remaining and b.remaining and a.remaining ~= b.remaining then return a.remaining < b.remaining end
        if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
        if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
      end
      if mode == "near" then
        if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
        if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
      end
      if mode == "level" then
        local la, lb = a.minLevel or 99, b.minLevel or 99
        if la ~= lb then return la < lb end
      end
      if mode ~= "level" and (a.zone or "") ~= (b.zone or "") then return (a.zone or "") < (b.zone or "") end
      return a.name < b.name
    end)
    self.rMatches = list
  end
  -- Header
  local total, collected, wanted = #(R.entries or {}), 0, 0
  for _, e in ipairs(R.entries or {}) do
    if R:IsCollected(e) then collected = collected + 1 elseif R:IsWanted(e) then wanted = wanted + 1 end
  end
  local frac = total > 0 and collected / total or 0
  self.rPercent:SetText(math.floor(frac * 100 + 0.5) .. "%")
  self.rTitle:SetText(L("rareCollection"))
  local radar = not PetSkillScoutDB or PetSkillScoutDB.rareRadarEnabled ~= false
  self.rSub:SetText(string.format(L("rareSummary"), collected, total, wanted, radar and L("radarOn") or L("radarOff")))
  self.rBar:SetFraction(frac, C.gold)
  self.rSearch.hint:SetText(L("rareSearchShort"))
  for _, b in ipairs(self.rModes) do
    b:SetText(L("mode_" .. b.mode))
    SetActive(b, b.mode == self.rareState.mode)
  end
  -- Grid
  local list = self.rMatches
  local rowsTotal = math.ceil(#list / TILE_COLS)
  FauxScrollFrame_Update(self.rScroll, rowsTotal, TILE_ROWS, TILE_H + TILE_GAP)
  local offset = FauxScrollFrame_GetOffset(self.rScroll) * TILE_COLS
  self.rEmpty:SetText(L("rareEmpty"))
  Show(self.rEmpty, #list == 0)
  for i, tile in ipairs(self.rTiles) do
    local e = list[i + offset]
    tile.entry = e
    if e then
      local tamed, want = R:IsCollected(e), R:IsWanted(e)
      tile.view:SetSubject({display=e.beast.displayID, npc=e.beast.npcID}, FamilyIcon(e.family))
      tile.name:SetText(e.name)
      local spd = R.Speed and R:Speed(e)
      tile.level:SetText(L("level") .. " " .. LevelText(e))
      local meta = (e.family and PSS:NameFamily(e.family) or "?")
      if e.dist then
        meta = meta .. "  ·  |cff8fe0a0" .. (e.approx and "~" or "") .. string.format(L("yardsDir"), math.floor(e.dist + 0.5), e.dir) .. "|r"
      else
        meta = meta .. "  ·  " .. (e.zone or "?")
      end
      tile.meta:SetText(meta)
      -- Attack speed on the right of the badge row; faster than 2.0 s in green.
      tile.speed:SetText(spd and string.format(L("rareAtk"), spd) or "")
      if spd and spd < 2 then tile.speed:SetTextColor(0.56, 0.88, 0.63) else tile.speed:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
      local kind, text = "none", L("badgeNotTamed")
      if tamed then kind, text = "tamed", L("rareTamed")
      elseif want then kind, text = "want", L("badgeWanted") end
      tile.badge:Set(kind, text)
      if e.new then tile.extra:Set("new", L("rareNew")); tile.extra:Show()
      elseif e.elite then tile.extra:Set("none", L("rareElite")); tile.extra:Show()
      else tile.extra:Hide() end
      -- Own sighting or the newer one shared by a guild / group member.
      local own, shared = R:LastSeen(e), PSS.Sync and PSS.Sync:Last(e)
      if shared and shared.t and (not (own and own.t) or shared.t > own.t) then
        tile.seen:SetText(PSS.Sync:Text(e))
        tile.seen:SetTextColor(0.56, 0.78, 1)
      else
        tile.seen:SetText(R:SeenText(e) or L("seenNever"))
        tile.seen:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
      local timerText, timerState = nil, nil
      if PSS.RareTimer then timerText, timerState = PSS.RareTimer:ShortText(e) end
      local queueText = PSS.Queue and PSS.Queue:TileText(e)
      if queueText then timerText = timerText and (queueText .. "  ·  " .. timerText) or queueText end
      tile.timer:SetText(timerText or "")
      if timerState == "open" or timerState == "late" then tile.timer:SetTextColor(0.49, 0.88, 0.64)
      elseif timerState == "wait" or timerState == "unknown" then tile.timer:SetTextColor(1, 0.71, 0.42)
      else tile.timer:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
      local edge = (want and not tamed) and STATUS.want.edge or (e.new and STATUS.new.edge) or nil
      SetEdgeColor(tile.pssEdges, edge or C.border, 1)
      tile:SetAlpha(tamed and 0.72 or 1)
      tile.want.icon:SetVertexColor(want and 0.94 or 0.62, want and 0.76 or 0.70, want and 0.37 or 0.62)
      tile.tamed.icon:SetVertexColor(tamed and 0.42 or 0.62, tamed and 0.86 or 0.70, tamed and 0.48 or 0.62)
      Show(tile.map, e.beast.mapID ~= nil)
      Show(tile.arrow, e.beast.mapID ~= nil)
      tile:Show()
    else
      tile:Hide()
    end
  end
end

-- Compatibility: older modules call these.
function UI:RefreshRare() if self.view == "rares" then self:UpdateRares(true) end end
function UI:UpdateRareList() if self.view == "rares" then self:UpdateRares() end end

---------------------------------------------------------------------------
-- Route: skill ranks to learn -> teaching beasts in a travel order
---------------------------------------------------------------------------
local ROUTE_ROWS, ROUTE_ROW_H = 9, 56

local function RouteSkills()
  local list = {}
  for key, info in pairs(PSS.Abilities) do
    if info.learn == "beast" then
      for _, b in ipairs(PSS.Beasts or {}) do
        if b.ability == key then table.insert(list, key) break end
      end
    end
  end
  table.sort(list, function(a, b) return PSS:NameAbility(a) < PSS:NameAbility(b) end)
  return list
end

local function BeastRanks(ability)
  local found, ranks = {}, {}
  for _, b in ipairs(PSS.Beasts or {}) do
    local r = tonumber(b.rank)
    if b.ability == ability and r and not found[r] then found[r] = true; table.insert(ranks, r) end
  end
  table.sort(ranks)
  return ranks
end

function UI:BuildRoute()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.route = p
  local st = self.routeState
  local skills = RouteSkills()
  st.skill = st.skill or skills[1]
  self.rtSkillDD = MakeDropdown(p, skills, function() return st.skill end, 210,
    function(v)
      st.skill = v
      st.rank = PSS.Route and PSS.Route:BestRank(v) or BeastRanks(v)[1]
      UI.rtRankDD:Sync()
    end,
    function(v) return L("skill") .. ": " .. PSS:NameAbility(v) end)
  self.rtSkillDD:SetPoint("TOPLEFT", p, "TOPLEFT", -16, 0)
  self.rtRankDD = MakeDropdown(p, function() return BeastRanks(st.skill) end, function() return st.rank end, 120,
    function(v) st.rank = v end, RankLabel)
  self.rtRankDD:SetPoint("TOPLEFT", p, "TOPLEFT", 200, 0)
  table.insert(self.dropdowns, self.rtSkillDD)
  table.insert(self.dropdowns, self.rtRankDD)
  self.rtAdd = MakeButton(p, "", 120, 32, function()
    local rank = st.rank or (PSS.Route and PSS.Route:BestRank(st.skill))
    if not rank then PSS:Print(L("routeNoRank")) return end
    if PSS.Route and not PSS.Route:Add(st.skill, rank) then PSS:Print(L("routeHave")) end
    UI:UpdateRoute()
  end, {size=12})
  self.rtAdd:SetPoint("TOPLEFT", p, "TOPLEFT", 346, 0)
  self.rtFill = MakeButton(p, "", 200, 32, function()
    local added = PSS.Route and PSS.Route:FillFromPet()
    if added == nil then PSS:Print(L("routeNoPet"))
    elseif added == 0 then PSS:Print(L("routeFillNone"))
    else PSS:Print(string.format(L("routeFilled"), added)) end
    UI:UpdateRoute()
  end, {size=12})
  self.rtFill:SetPoint("TOPLEFT", p, "TOPLEFT", 474, 0)
  self.rtClear = MakeButton(p, "", 110, 32, function()
    if PSS.Route then PSS.Route:Clear() end
    UI:UpdateRoute()
  end, {size=12})
  self.rtClear:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  self.rtGo = MakeButton(p, "", 180, 32, function()
    if PSS.Route and not PSS.Route:Go() then PSS:Print(L("routeNothing")) end
    UI:UpdateRoute()
  end, {icon="Interface\\Minimap\\MinimapArrow", iconSize=18, iconLeft=true, size=12})
  self.rtGo:SetPoint("RIGHT", self.rtClear, "LEFT", -8, 0)
  self.rtSummary = Label(p, "", 12, C.muted, BODY_W - 400, "LEFT", true)
  self.rtSummary:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -46)
  -- Nearest hunter / pet trainer: map and arrow.
  self.rtPetTr = MakeButton(p, "", 190, 24, function() PSS.Trainers:Show("pet") end,
    {icon="Interface\\Minimap\\MinimapArrow", iconSize=14, iconLeft=true, size=11})
  self.rtPetTr:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -40)
  self.rtHuntTr = MakeButton(p, "", 190, 24, function() PSS.Trainers:Show("hunter") end,
    {icon="Interface\\Minimap\\MinimapArrow", iconSize=14, iconLeft=true, size=11})
  self.rtHuntTr:SetPoint("RIGHT", self.rtPetTr, "LEFT", -8, 0)

  self.rtScroll = CreateFrame("ScrollFrame", "PetSkillScoutRouteScroll", p, "FauxScrollFrameTemplate")
  self.rtScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -72)
  self.rtScroll:SetSize(BODY_W - 24, ROUTE_ROWS * ROUTE_ROW_H)
  self.rtScroll:SetScript("OnVerticalScroll", function(f, offset)
    FauxScrollFrame_OnVerticalScroll(f, offset, ROUTE_ROW_H, function() UI:UpdateRoute(true) end)
  end)
  self.rtRows = {}
  local rw = BODY_W - 24
  for i = 1, ROUTE_ROWS do
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(rw, ROUTE_ROW_H - 6)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -72 - (i - 1) * ROUTE_ROW_H)
    Panel(row, C.surface)
    row.bar = Solid(row, "OVERLAY", C.gold, 1)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    row.num = Label(row, "", 16, C.gold, 30, "CENTER", true)
    row.num:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", row, "LEFT", 42, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = Label(row, "", 14, C.cream, 300, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 88, -8)
    row.sub = Label(row, "", 11, C.muted, 300, "LEFT", true)
    row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 88, -29)
    row.zone = Label(row, "", 13, C.cream, 250, "LEFT", true)
    row.zone:SetPoint("TOPLEFT", row, "TOPLEFT", 400, -8)
    row.dist = Label(row, "", 11, C.muted, 250, "LEFT", true)
    row.dist:SetPoint("TOPLEFT", row, "TOPLEFT", 400, -29)
    row.status = Label(row, "", 12, C.muted, 200, "LEFT", true)
    row.status:SetPoint("LEFT", row, "LEFT", 664, 0)
    row.remove = MakeButton(row, "X", 30, 30, function(b)
      if b.index and PSS.Route then PSS.Route:Remove(b.index) end
      UI:UpdateRoute()
    end, {size=12})
    row.remove:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    SetTip(row.remove, function() return L("routeRemove") end)
    row.other = IconButton(row, "Interface\\Icons\\INV_Misc_Dice_01", 30, function(b)
      if b.goal and PSS.Route then PSS.Route:NextChoice(b.goal) end
      UI:UpdateRoute()
    end, function() return L("routeOther") end)
    row.other:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
    row.arrow = IconButton(row, "Interface\\Minimap\\MinimapArrow", 30, function(b)
      if b.stop and PSS.Route and PSS.Nav then PSS.Nav:SetTarget(PSS.Route:Target(b.stop)) end
    end, function() return L("arrowButton") end)
    row.arrow:SetPoint("RIGHT", row.other, "LEFT", -6, 0)
    row.map = IconButton(row, TEX .. "Rare_map", 30, function(b)
      if b.stop and b.stop.beast and PSS.Map then PSS.Map:Show(b.stop.beast) end
    end, function() return L("map") end)
    row.map:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
    ForwardWheel(row, self.rtScroll, ROUTE_ROW_H)
    self.rtRows[i] = row
  end
  self.rtEmpty = Label(p, "", 13, C.muted, 700, "LEFT")
  self.rtEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -92)
  self.rtHint = Label(p, "", 11, C.muted, BODY_W, "LEFT")
  self.rtHint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 4)
end

local function GoalsText(goals)
  local parts = {}
  for _, g in ipairs(goals) do table.insert(parts, PSS:NameAbility(g.a) .. " " .. g.r) end
  return table.concat(parts, ", ")
end

function UI:UpdateRoute(scrollOnly)
  if not self.rtRows then return end
  local R = PSS.Route
  if not R then return end
  if not scrollOnly or not self.rtStops then self.rtStops = R:Stops() end
  local stops = self.rtStops
  local st = self.routeState
  if st.skill and not st.rank then st.rank = R:BestRank(st.skill) or BeastRanks(st.skill)[1] end
  self.rtAdd:SetText(L("routeAdd"))
  self.rtFill:SetText(L("routeFill"))
  self.rtClear:SetText(L("routeClear"))
  self.rtGo:SetText(L("routeGo"))
  self.rtHuntTr:SetText(L("trHunter"))
  self.rtPetTr:SetText(L("trPet"))
  self.rtSkillDD:Sync()
  self.rtRankDD:Sync()
  -- Summary: stops left, zones, the next stop.
  local open, zones, seenZone, nextStop = 0, 0, {}, nil
  for _, s in ipairs(stops) do
    if not s.done and not s.noBeast then
      open = open + 1
      nextStop = nextStop or s
      local z = s.beast.zone or "?"
      if not seenZone[z] then seenZone[z] = true; zones = zones + 1 end
    end
  end
  if #stops == 0 then
    self.rtSummary:SetText(L("routeSummaryEmpty"))
  else
    local text = string.format(L("routeSummary"), open, zones)
    if nextStop then
      text = text .. "  ·  " .. string.format(L("routeNextIs"), nextStop.beast.name, nextStop.beast.zone or "?")
    elseif open == 0 then
      text = text .. "  ·  |cff7ee0a3" .. L("routeFinished") .. "|r"
    end
    self.rtSummary:SetText(text)
  end
  self.rtEmpty:SetText(L("routeEmpty"))
  Show(self.rtEmpty, #stops == 0)
  self.rtHint:SetText(L("routeHint"))
  FauxScrollFrame_Update(self.rtScroll, #stops, ROUTE_ROWS, ROUTE_ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.rtScroll)
  local goals = R:Goals()
  local function GoalIndex(goal)
    for i, g in ipairs(goals) do if g == goal then return i end end
  end
  local petLevel = PSS.MyPet and PSS.MyPet.active and tonumber(PSS.MyPet.level)
  for i, row in ipairs(self.rtRows) do
    local s = stops[i + offset]
    if s then
      local b = s.beast
      row.num:SetText(tostring(i + offset))
      row.stop, row.arrow.stop, row.map.stop = s, s, s
      row.other.goal = s.goals[1]
      row.remove.index = GoalIndex(s.goals[1])
      -- Pet level needed for the highest rank of this stop.
      local needPet
      for _, g in ipairs(s.goals) do
        local meta = PSS.Ranks[g.a] and PSS.Ranks[g.a][tonumber(g.r)]
        if meta and meta.petLevel and (not needPet or meta.petLevel > needPet) then needPet = meta.petLevel end
      end
      if b then
        row.icon:SetTexture(FamilyIcon(b.family))
        row.name:SetText(b.name)
        local sub = GoalsText(s.goals) .. "  ·  " .. PSS:NameFamily(b.family) .. "  ·  " .. L("level") .. " " .. LevelText(b)
        row.sub:SetText(sub)
        row.zone:SetText(b.zone or "?")
        local dist
        if s.otherContinent then dist = L("routeOtherContinent")
        elseif s.dist then dist = PSS.Nav:DistanceText(s.dist) end
        if s.choices and s.choices > 1 then
          dist = (dist and (dist .. "  ·  ") or "") .. string.format(L("routeChoices"), s.choices)
        end
        row.dist:SetText(dist or "")
      else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(GoalsText(s.goals))
        row.sub:SetText(L("routeNoBeast"))
        row.zone:SetText("")
        row.dist:SetText("")
      end
      local status, color = "", C.muted
      if s.done then status, color = L("routeDone"), {0.49, 0.88, 0.64}
      elseif s.noBeast then status = L("routeNoBeastShort")
      elseif not s.canTame then status, color = string.format(L("routeTooHigh"), b.minLevel or 0), {1, 0.48, 0.36}
      elseif s == nextStop then status, color = L("routeNext"), C.gold
      elseif needPet and petLevel and petLevel < needPet then status = string.format(L("routeNeedPet"), needPet) end
      if status == "" and needPet then status = string.format(L("routePetLevel"), needPet) end
      row.status:SetText(status)
      row.status:SetTextColor(color[1], color[2], color[3])
      Show(row.bar, s == nextStop)
      row:SetAlpha(s.done and 0.6 or 1)
      Show(row.arrow, b ~= nil and not s.done)
      Show(row.map, b ~= nil)
      Show(row.other, (s.choices or 0) > 1 and not s.done)
      row:Show()
    else
      row:Hide()
    end
  end
end

---------------------------------------------------------------------------
-- Gear: best items per slot for a hunter spec (WoW Forever)
---------------------------------------------------------------------------
local GEAR_ROW_H = 34 -- row pitch is GEAR_ROW_H - 1
UI.gearState = UI.gearState or {mode = "now", alt = {}}

local function GearTooltip(row)
  local e = row.entry
  local pick = e and e.pick
  if not pick then return end
  local G = PSS.Gear
  local rec = pick.rec
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then
    pcall(GameTooltip.SetItemByID, GameTooltip, rec.id)
  else
    pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. rec.id)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L("gearSources"), C.gold[1], C.gold[2], C.gold[3])
  for _, line in ipairs(G:SourceLines(rec)) do GameTooltip:AddLine(line, 1, 1, 1, true) end
  local eq = e.equipped.score or 0
  local gain = e.gain and string.format("%+d%%", math.floor(e.gain + 0.5)) or "—"
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(string.format(L("gearScore"), math.floor(eq + 0.5), math.floor(pick.score + 0.5)),
    C.muted[1], C.muted[2], C.muted[3], true)
  local diff = G:Diff(G:Stats(rec.id), e.equipped.st, rec.slot)
  if diff ~= "" then GameTooltip:AddLine(diff, 1, 1, 1, true) end
  if e.equipped.link then GameTooltip:AddLine(string.format(L("gearEquipped"), e.equipped.link), C.muted[1], C.muted[2], C.muted[3], true) end
  GameTooltip:AddLine(L("gearApExplain"), C.muted[1], C.muted[2], C.muted[3], true)
  GameTooltip:AddLine(L("gearTipHint"), C.muted[1], C.muted[2], C.muted[3], true)
  GameTooltip:Show()
end

-- Places a pair of labels as one block: two lines around the middle of the
-- row, or the first line alone in the middle.
local function TwoLines(row, top, bottom, x)
  top:ClearAllPoints(); bottom:ClearAllPoints()
  local two = (bottom:GetText() or "") ~= ""
  top:SetPoint("LEFT", row, "LEFT", x, two and 7 or 0)
  bottom:SetPoint("LEFT", row, "LEFT", x, -8)
  Show(bottom, two)
end

function UI:BuildGear()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.gear = p
  local st = self.gearState
  -- Spec.
  self.gearSpecBtns = {}
  for i, spec in ipairs({"BM", "MM", "SV"}) do
    local b = MakeButton(p, "", 118, 30, function()
      PSS.Gear:SetSpec(spec); st.alt = {}; UI:UpdateGear()
    end, {size = 12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 122, 0)
    b.spec = spec
    self.gearSpecBtns[i] = b
  end
  -- Mode.
  self.gearNow = MakeButton(p, "", 150, 30, function() st.mode = "now"; st.alt = {}; UI:UpdateGear() end, {size = 12})
  self.gearNow:SetPoint("TOPLEFT", p, "TOPLEFT", 376, 0)
  self.gearMax = MakeButton(p, "", 160, 30, function() st.mode = "max"; st.alt = {}; UI:UpdateGear() end, {size = 12})
  self.gearMax:SetPoint("LEFT", self.gearNow, "RIGHT", 4, 0)
  self.gearRaids = MakeButton(p, "", 100, 30, function()
    if PetSkillScoutDB then PetSkillScoutDB.gearRaids = not PetSkillScoutDB.gearRaids end
    st.alt = {}; UI:UpdateGear()
  end, {size = 12})
  self.gearRaids:SetPoint("LEFT", self.gearMax, "RIGHT", 12, 0)
  SetTip(self.gearRaids, function() return L("gearRaidsTip") end)
  self.gearRare = MakeButton(p, "", 150, 30, function()
    if PetSkillScoutDB then PetSkillScoutDB.gearRare = not PetSkillScoutDB.gearRare end
    st.alt = {}; UI:UpdateGear()
  end, {size = 12})
  self.gearRare:SetPoint("LEFT", self.gearRaids, "RIGHT", 4, 0)
  SetTip(self.gearRare, function() return L("gearRareTip") end)
  self.gearPvp = MakeButton(p, "", 100, 30, function()
    if PetSkillScoutDB then PetSkillScoutDB.gearPvp = not PetSkillScoutDB.gearPvp end
    st.alt = {}; UI:UpdateGear()
  end, {size = 12})
  self.gearPvp:SetPoint("LEFT", self.gearRare, "RIGHT", 4, 0)
  SetTip(self.gearPvp, function() return L("gearPvpTip") end)
  self.gearSummary = Label(p, "", 11, C.gold, 300, "RIGHT", true)
  self.gearSummary:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -2, 0)

  -- Columns: slot | item | gain | what changes | where to get it.
  local COL = {slot = 10, icon = 100, item = 134, gain = 440, diff = 548, src = 792, alt = BODY_W - 34}
  self.gearCols = COL
  local head = CreateFrame("Frame", nil, p)
  head:SetSize(BODY_W, 16)
  head:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -38)
  self.gearHead = {}
  for _, def in ipairs({{"slot", COL.slot, 80, "LEFT"}, {"item", COL.item, 300, "LEFT"}, {"gain", COL.gain, 96, "CENTER"},
    {"diff", COL.diff, 230, "LEFT"}, {"src", COL.src, 230, "LEFT"}}) do
    local h = Label(head, "", 10, C.muted, def[3], def[4], true)
    h:SetPoint("LEFT", head, "LEFT", def[2], 0)
    self.gearHead[def[1]] = h
  end
  self.gearRows = {}
  local top = 56
  local RH = GEAR_ROW_H - 1
  for i, def in ipairs(PSS.Gear.SLOTS) do
    local row = CreateFrame("Button", nil, p)
    row:SetSize(BODY_W, RH - 2)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -top - (i - 1) * RH)
    Panel(row, C.surface)
    row.bar = Solid(row, "OVERLAY", C.green, 1)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    row.slot = Label(row, "", 12, C.muted, 86, "LEFT", true)
    row.slot:SetPoint("LEFT", row, "LEFT", COL.slot, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row, "LEFT", COL.icon, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Two-line blocks: line 1 above the middle, line 2 below it; a block
    -- with only one line is centred.
    row.name = Label(row, "", 13, C.cream, 296, "LEFT", true)
    row.sub = Label(row, "", 10, C.muted, 296, "LEFT", true)
    row.gain = Label(row, "", 15, C.green, 96, "CENTER", true)
    row.gain:SetPoint("LEFT", row, "LEFT", COL.gain, 0)
    row.diff = Label(row, "", 11, C.cream, 236, "LEFT", true)
    row.diff:SetPoint("LEFT", row, "LEFT", COL.diff, 0)
    row.src = Label(row, "", 12, C.cream, 236, "LEFT", true)
    row.src2 = Label(row, "", 10, C.muted, 236, "LEFT", true)
    row.alt = IconButton(row, "Interface\\Icons\\INV_Misc_Dice_01", 22, function(b)
      local key = b.key
      if not key then return end
      st.alt[key] = (st.alt[key] or 0) + 1
      UI:UpdateGear()
    end, function(b) return b.tip or L("gearOther") end)
    row.alt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    -- Where the reward quest starts: arrow to the quest giver + world map on its zone.
    row.where = IconButton(row, "Interface\\Icons\\INV_Misc_Map_01", 22, function(b)
      local id, r = b.questID, b.quest
      if not (id and r and r.m and r.x) then
        if b.qname then PSS:Print(string.format(L("gearQuestUnknown"), b.qname)) end
        return
      end
      local W = PSS.QuestWorth
      local giver = (W and W:NPCName(r.g)) or r.gn
      local t = {name = giver or r.n, mapID = r.m, points = {{r.x, r.y}}}
      if PSS.Nav then PSS.Nav:SetTarget(t) end
      UI:OpenQuestMap(nil, r.m, t)
    end, function(b)
      local r = b.quest
      if not (r and r.m and r.x) then return string.format(L("gearQuestUnknown"), b.qname or "?") end
      local W = PSS.QuestWorth
      local zone = r.m and C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, r.m))
      zone = type(zone) == "table" and zone.name or "?"
      local lines = {string.format(L("gearQuestFrom"), (W and W:NPCName(r.g)) or r.gn or L("qwGiverUnknown"))}
      lines[#lines + 1] = string.format("%s  %.1f, %.1f", zone, r.x or 0, r.y or 0)
      if r.l then lines[#lines + 1] = string.format(L("qFrom"), r.l) end
      if b.chain and b.chain > 1 then lines[#lines + 1] = string.format(L("gearQuestChain"), b.chain) end
      if r.learned then
        lines[#lines + 1] = r.confirmed and string.format(L("gearQuestLearned"), r.reporters or 1) or L("gearQuestUnverified")
      end
      lines[#lines + 1] = L("gearQuestWhereHint")
      return table.concat(lines, "\n")
    end)
    row.where:SetPoint("RIGHT", row.alt, "LEFT", -4, 0)
    row:SetScript("OnEnter", GearTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(r)
      local e = r.entry
      if e and e.pick and IsShiftKeyDown and IsShiftKeyDown() then
        local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.pick.rec.id)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
      end
    end)
    row.def = def
    self.gearRows[i] = row
  end
  self.gearHint = Label(p, "", 10, C.muted, BODY_W - 320, "LEFT", true)
  self.gearHint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 0)
end

function UI:UpdateGear()
  if not self.gearRows then return end
  local G = PSS.Gear
  local st = self.gearState
  local spec = G:Spec()
  for _, b in ipairs(self.gearSpecBtns) do
    b:SetText(L("gearSpec" .. b.spec))
    SetActive(b, b.spec == spec)
  end
  local cap = G:MaxLevel()
  self.gearNow:SetText(L("gearModeNow"))
  self.gearMax:SetText(string.format(L("gearModeMax"), cap))
  SetActive(self.gearNow, st.mode ~= "max")
  SetActive(self.gearMax, st.mode == "max")
  self.gearRaids:SetText(L("gearRaids") .. ": " .. L(G:IncludeRaids() and "gearYes" or "gearNo"))
  SetActive(self.gearRaids, G:IncludeRaids())
  self.gearRare:SetText(L("gearRareDrops") .. ": " .. L(G:IncludeRare() and "gearYes" or "gearNo"))
  SetActive(self.gearRare, G:IncludeRare())
  self.gearPvp:SetText("PvP: " .. L(G:IncludePvp() and "gearYes" or "gearNo"))
  SetActive(self.gearPvp, G:IncludePvp())
  local plan, level = G:Plan(st.mode == "max" and "max" or "now", spec)
  local upgrades = 0
  for i, row in ipairs(self.gearRows) do
    local e = plan[i]
    local key = e.slot.key
    -- Alternative picks (dice): cycle through the next best items.
    local choices = {}
    if e.pick then choices[1] = e.pick end
    for _, a in ipairs(e.alts) do if #choices < 6 then choices[#choices + 1] = a end end
    local n = #choices
    local idx = n > 0 and ((st.alt[key] or 0) % n) + 1 or 1
    if n > 0 and idx > 1 then
      local c = choices[idx]
      e = {slot = e.slot, equipped = e.equipped, alts = e.alts, pick = c, locked = e.locked, twoHand = e.twoHand}
      local eq = e.equipped.score or 0
      e.wearing = e.equipped.id == c.rec.id
      if eq > 0 and not e.wearing then e.gain = (c.score - eq) / eq * 100 end
      e.better = c.score > eq + 0.5 and not e.wearing
    end
    row.entry = e
    row.slot:SetText(L("slot_" .. key))
    row.alt.key = key
    row.alt.tip = string.format(L("gearOtherN"), idx, math.max(n, 1))
    Show(row.alt, n > 1)
    local eqName
    if e.equipped.link then eqName = e.equipped.link:match("%[(.-)%]") end
    local COL = self.gearCols
    if e.pick then
      local rec = e.pick.rec
      local name, color = G:Name(rec)
      local eq = e.equipped.score or 0
      -- Your own item is better: show it instead of a weaker suggestion.
      local keep = st.mode ~= "max" and not e.wearing and eq > 0 and e.pick.score <= eq + 0.5
      row.icon:SetDesaturated(false)
      if keep then
        row.icon:SetTexture(e.equipped.id and G:Icon(e.equipped.id) or G:Icon(rec.id))
        row.name:SetText(eqName or name)
        row.name:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
        row.sub:SetText("")
      else
        row.icon:SetTexture(G:Icon(rec.id))
        row.name:SetText(name)
        row.name:SetTextColor(color[1], color[2], color[3])
        local sub = string.format(L("gearLvlShort"), rec.lvl)
        if not e.equipped.link and not e.wearing then sub = sub .. "  ·  " .. L("gearNone") end
        row.sub:SetText(sub)
      end
      -- What changes: up to three stats, gains green, losses red.
      if keep then
        row.diff:SetText(L("gearYoursBestSub"))
        row.diff:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      elseif e.wearing then
        row.diff:SetText("")
      else
        local parts = G:DiffParts(G:Stats(rec.id), e.equipped.st, rec.slot, 3)
        local out = {}
        for _, part in ipairs(parts) do
          table.insert(out, (part.up and "|cff7ee0a3" or "|cffff7a7a") .. part.text .. "|r")
        end
        row.diff:SetText(table.concat(out, "   "))
        row.diff:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
      end
      -- Where to get it: who / what on top, kind · place · chance below.
      if keep then
        row.src:SetText(""); row.src2:SetText("")
      else
        local title, detail = G:SourceShort(rec)
        row.src:SetText(title or "")
        row.src2:SetText(detail or "")
      end
      local qid, qr, qchain
      if not keep then qid, qr, qchain = G:QuestFor(rec) end
      row.where.questID, row.where.quest, row.where.chain = qid, qr, qchain
      row.where.qname = (not keep) and G:QuestSourceName(rec) or nil
      local known = qr and qr.m and qr.x and true or false
      -- Every quest reward gets the button; grey when the giver is not in the database.
      Show(row.where, known or row.where.qname ~= nil)
      row.where.icon:SetDesaturated(not known)
      row.where:SetAlpha((known and not (qr.learned and not qr.confirmed)) and 1 or (known and 0.8 or 0.55))
      -- Gain in attack power.
      local delta = math.floor(e.pick.score - eq + 0.5)
      if e.wearing then
        row.gain:SetText(L("gearWearing")); row.gain:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        row.gain:SetFont(FONT, 12, "")
      elseif keep then
        row.gain:SetText("—"); row.gain:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        row.gain:SetFont(FONT, 15, "")
      else
        row.gain:SetText(string.format("%+d", delta))
        row.gain:SetFont(FONT, 15, "")
        if delta > 0 then row.gain:SetTextColor(C.green[1], C.green[2], C.green[3])
        else row.gain:SetTextColor(C.red[1], C.red[2], C.red[3]) end
      end
      e.better = e.better and not keep
      if e.better then upgrades = upgrades + 1 end
      Show(row.bar, e.better and st.mode ~= "max")
      row:SetAlpha(1)
      G:Request(rec.id)
    else
      row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      row.icon:SetDesaturated(true)
      local text = e.twoHand and L("gearTwoHand") or (e.locked and string.format(L("gearDualAt"), e.locked) or L("gearNothing"))
      local up = e.upcoming and not e.twoHand and not e.locked and e.upcoming.rec
      if up then
        -- Empty slot, nothing at your level yet: the first item that comes later.
        row.icon:SetTexture(G:Icon(up.id))
        row.icon:SetDesaturated(true)
        text = G:Name(up)
      end
      row.name:SetText(PSS:Safe(text))
      row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      if up then
        row.sub:SetText(string.format(L("gearFromLevel"), up.lvl))
      else
        row.sub:SetText(eqName and string.format(L("gearEquipped"), eqName) or "")
      end
      row.src:SetText(""); row.src2:SetText(""); row.gain:SetText(""); row.diff:SetText("")
      if up then
        local l1, l2 = G:SourceShort(up)
        row.src:SetText(PSS:Safe(l1 or "")); row.src2:SetText(PSS:Safe(l2 or ""))
        G:Request(up.id)
      end
      row.where.questID, row.where.quest, row.where.qname = nil, nil, nil
      Show(row.where, false)
      Show(row.bar, false)
      row:SetAlpha(0.7)
    end
    TwoLines(row, row.name, row.sub, COL.item)
    TwoLines(row, row.src, row.src2, COL.src)
  end
  local hd = self.gearHead
  hd.slot:SetText(L("gearColSlot")); hd.item:SetText(L("gearColItem")); hd.gain:SetText(L("gearColGain"))
  hd.diff:SetText(L("gearColDiff")); hd.src:SetText(L("gearColSrc"))
  if st.mode == "max" then
    self.gearSummary:SetText(string.format(L("gearSummaryMax"), cap))
  else
    self.gearSummary:SetText(string.format(L("gearSummaryNow"), level, upgrades))
  end
  self.gearHint:SetText(L("gearHint"))
end

---------------------------------------------------------------------------
-- Quests: hunter quest chains with strong rewards, nearby quests and the
-- quest log, each rated by experience per minute and gear (QuestWorth).
---------------------------------------------------------------------------
local QUEST_ROWS, QUEST_ROW_H, QUEST_TOP = 9, 60, 66
UI.questState = UI.questState or {filter = "ready", mode = "hunter"}
local QUEST_QUALITY = {[2] = {0.12, 1, 0}, [3] = {0, 0.44, 0.87}, [4] = {0.64, 0.21, 0.93}, [5] = {1, 0.5, 0}}
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"

local function QuestTags(Q, e)
  local tags = {}
  if e.tag == "dungeon" then tags[#tags + 1] = string.format(L("qTagDungeon"), e.inst or "?")
  elseif e.tag == "raid" then tags[#tags + 1] = string.format(L("qTagRaid"), e.inst or "?")
  elseif e.tag then tags[#tags + 1] = L("qTag_" .. e.tag) end
  if e.forever == "new" then tags[#tags + 1] = "|cff7ee0a3" .. L("qNew") .. "|r"
  elseif e.forever == "changed" then tags[#tags + 1] = "|cff7ee0a3" .. L("qChanged") .. "|r" end
  if e.unconfirmed then tags[#tags + 1] = L("qUnconfirmed") end
  return tags
end

-- Rating lines shared by rows and tooltips.
local function RateLines(rate)
  local W = PSS.QuestWorth
  local hex = W.HEX[rate.verdict] or ""
  return hex .. L("qw_" .. rate.verdict) .. "|r", W:Summary(rate)
end

local function HunterTooltip(row, r)
  local Q, e = PSS.Quests, r.e
  local info = Q:Info(e)
  GameTooltip:AddLine(PSS:Safe(Q:Title(e)), C.gold[1], C.gold[2], C.gold[3])
  local where = Q:ZoneName(e)
  if info.npc then where = string.format(L("qGiver"), info.npc) .. ", " .. where end
  GameTooltip:AddLine(PSS:Safe(where), 1, 1, 1, true)
  GameTooltip:AddLine(PSS:Safe(string.format(L("qFrom"), Q:MinLevel(e))), C.muted[1], C.muted[2], C.muted[3])
  local tags = QuestTags(Q, e)
  if #tags > 0 then GameTooltip:AddLine(PSS:Safe(table.concat(tags, ", ")), C.muted[1], C.muted[2], C.muted[3], true) end
  if e.note then GameTooltip:AddLine(PSS:Safe(L(e.note)), 1, 1, 1, true) end
  if e.quests and #e.quests > 1 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L("qChain"), C.gold[1], C.gold[2], C.gold[3])
    for i, id in ipairs(e.quests) do
      local t = Q:QuestTitle(id) or ("#" .. id)
      local mark = Q:QuestDone(id) and "|cff7ee0a3+|r " or (Q:InLogQuest(id) and "|cffffd100>|r " or "- ")
      GameTooltip:AddLine(PSS:Safe(mark .. i .. ". " .. t), 1, 1, 1)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L(#(e.items or {}) > 1 and "qRewardChoice" or "qReward"), C.gold[1], C.gold[2], C.gold[3])
  local G = PSS.Gear
  local _, _, eqScore = G:Equipped(18, G:Spec())
  for _, id in ipairs(e.items or {}) do
    local name, _, q = Q:ItemName(e, id)
    local c = QUEST_QUALITY[q or 0] or {1, 1, 1}
    local text = name
    if e.kind == "ranged" then
      local st = G:Stats(id)
      if st then text = text .. string.format("  (%+d)", math.floor(G:Score(st, "ranged") - (eqScore or 0) + 0.5)) end
    end
    GameTooltip:AddLine(PSS:Safe(text), c[1], c[2], c[3])
  end
  if e.req then GameTooltip:AddLine(PSS:Safe(string.format(L("qUseAt"), e.req)), C.muted[1], C.muted[2], C.muted[3]) end
  if info.quest and PSS.QuestDB and PSS.QuestDB[info.quest] then
    local a, b = RateLines(PSS.QuestWorth:Rate(info.quest))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(PSS:Safe(a .. "  " .. b), 1, 1, 1, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L("qTipHint"), C.muted[1], C.muted[2], C.muted[3], true)
end

local function QuestRowTooltip(id, rate)
  local W = PSS.QuestWorth
  local rec = W:Record(id)
  GameTooltip:AddLine(PSS:Safe(W:Title(id)), C.gold[1], C.gold[2], C.gold[3])
  if rec then
    local where = {}
    local npc = W:NPCName(rec.g)
    if npc then where[#where + 1] = string.format(L("qGiver"), npc) end
    if rec.l then where[#where + 1] = string.format(L("qFrom"), rec.l) end
    if #where > 0 then GameTooltip:AddLine(PSS:Safe(table.concat(where, ", ")), 1, 1, 1, true) end
    if rec.d then GameTooltip:AddLine(L("qwDungeon"), C.muted[1], C.muted[2], C.muted[3]) end
    if rec.b then GameTooltip:AddLine(L("qwBreadcrumb"), C.muted[1], C.muted[2], C.muted[3]) end
  end
  local a, b = RateLines(rate)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(PSS:Safe(a), 1, 1, 1)
  GameTooltip:AddLine(PSS:Safe(b), 1, 1, 1, true)
  GameTooltip:AddLine(PSS:Safe(string.format(L("qwRatio"), rate.ratio)), C.muted[1], C.muted[2], C.muted[3], true)
  if rec and rec.i then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L(#rec.i > 1 and "qRewardChoice" or "qReward"), C.gold[1], C.gold[2], C.gold[3])
    for _, item in ipairs(rec.i) do
      local qi = PSS.QuestItems and PSS.QuestItems[item]
      local name = PSS.Quests:ItemName({}, item)
      local c = QUEST_QUALITY[qi and qi.q or 0] or {1, 1, 1}
      local text = name
      if PSS.GearCompare then
        local res = PSS.GearCompare:Compare("item:" .. item)
        if res and res.delta and res.canUse ~= false then text = text .. string.format("  (%+d)", math.floor(res.delta + 0.5)) end
      end
      GameTooltip:AddLine(PSS:Safe(text), c[1], c[2], c[3])
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L(rate.xpExact and "qwExact" or "qwEstimate"), C.muted[1], C.muted[2], C.muted[3], true)
end

local function QuestTooltip(row)
  local r = row.data
  if not r then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if r.e then HunterTooltip(row, r) else QuestRowTooltip(r.id, r.rate) end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Network tab: hunters online and the live feed of the hunter network.
---------------------------------------------------------------------------
local NET_ROWS, NET_ROW_H = 18, 28
local ON_ROWS, ON_ROW_H = 17, 30
function UI:BuildNetwork()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.network = p
  self.netState = self.netState or {filter = "all", mine = true, offset = 0}
  local st = self.netState

  -- Left: hunters online.
  local left = CreateFrame("Frame", nil, p)
  left:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  left:SetSize(330, BODY_H - 30)
  Panel(left, C.surface)
  self.netOnHead = Label(left, "", 14, C.gold, 300, "LEFT", true)
  self.netOnHead:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -12)
  self.netStatus = Label(left, "", 11, C.muted, 300, "LEFT", true)
  self.netStatus:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -34)
  self.netOnRows = {}
  for i = 1, ON_ROWS do
    local row = CreateFrame("Frame", nil, left)
    row:SetSize(306, ON_ROW_H - 2)
    row:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -56 - (i - 1) * ON_ROW_H)
    row.name = Label(row, "", 13, C.cream, 150, "LEFT", true)
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.info = Label(row, "", 10, C.muted, 150, "RIGHT", true)
    row.info:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    self.netOnRows[i] = row
  end

  -- Right: filters + feed.
  local x0 = 346
  self.netFilters = {}
  for i, f in ipairs({"all", "quest", "rare", "hunter", "other"}) do
    local b = MakeButton(p, "", 108, 30, function() st.filter = f; st.offset = 0; UI:UpdateNetwork() end, {size = 12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", x0 + (i - 1) * 112, 0)
    b.filter = f
    self.netFilters[i] = b
  end
  self.netMine = MakeButton(p, "", 150, 30, function() st.mine = not st.mine; st.offset = 0; UI:UpdateNetwork() end, {size = 12})
  self.netMine:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  local feed = CreateFrame("Frame", nil, p)
  feed:SetPoint("TOPLEFT", p, "TOPLEFT", x0, -40)
  feed:SetSize(BODY_W - x0, NET_ROWS * NET_ROW_H + 8)
  Panel(feed, C.surface)
  feed:EnableMouseWheel(true)
  feed:SetScript("OnMouseWheel", function(_, delta)
    st.offset = math.max(0, (st.offset or 0) - delta * 3)
    UI:UpdateNetwork()
  end)
  self.netFeedRows = {}
  for i = 1, NET_ROWS do
    local row = CreateFrame("Frame", nil, feed)
    row:SetSize(BODY_W - x0 - 24, NET_ROW_H - 2)
    row:SetPoint("TOPLEFT", feed, "TOPLEFT", 12, -6 - (i - 1) * NET_ROW_H)
    row.time = Label(row, "", 11, C.muted, 46, "LEFT", true)
    row.time:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.text = Label(row, "", 12, C.cream, BODY_W - x0 - 90, "LEFT", true)
    row.text:SetPoint("LEFT", row, "LEFT", 52, 0)
    self.netFeedRows[i] = row
  end
  self.netEmpty = Label(feed, "", 12, C.muted, BODY_W - x0 - 40, "LEFT")
  self.netEmpty:SetPoint("TOPLEFT", feed, "TOPLEFT", 14, -14)
  self.netStats = Label(p, "", 11, C.muted, BODY_W - x0, "LEFT", true)
  self.netStats:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", x0, 4)
end

local function Ago(t)
  local s = math.max(0, (time and time() or 0) - (t or 0))
  if s < 60 then return L("netNow") end
  return string.format(L("netMin"), math.floor(s / 60))
end

function UI:NetEventText(e)
  local who = "|cff" .. string.format("%02x%02x%02x", C.gold[1] * 255, C.gold[2] * 255, C.gold[3] * 255) .. PSS:Safe(e.who or "?") .. "|r"
  local a, b = PSS:Safe(tostring(e.a or "?")), PSS:Safe(tostring(e.b or "?"))
  return string.format(L("nf_" .. e.kind), who, a, b)
end

function UI:UpdateNetwork()
  if not self.netOnRows then return end
  local F, N = PSS.NetFeed, PSS.Net
  local st = self.netState
  local on = N and N:ChannelID()
  -- Hunters online (you first).
  local list = F and F:Online() or {}
  local me = UnitName and UnitName("player") or "?"
  table.insert(list, 1, {name = me, t = time and time() or 0, v = PSS.version, me = true})
  self.netOnHead:SetText(string.format(L("netOnlineHead"), #list))
  self.netStatus:SetText(on and L("netStatusOn") or L("netStatusOff"))
  self.netStatus:SetTextColor(on and 0.45 or 0.95, on and 0.85 or 0.45, on and 0.5 or 0.4)
  for i, row in ipairs(self.netOnRows) do
    local h = list[i]
    if i == ON_ROWS and #list > ON_ROWS then
      row.name:SetText(string.format(L("netMore"), #list - ON_ROWS + 1)); row.info:SetText(""); row:Show()
    elseif h then
      row.name:SetText(PSS:Safe(h.name) .. (h.me and (" (" .. L("netYou") .. ")") or ""))
      if h.guild then row.name:SetTextColor(C.green[1], C.green[2], C.green[3])
      else row.name:SetTextColor(C.cream[1], C.cream[2], C.cream[3]) end
      local old = N and N.Newer and h.v and N.Newer(PSS.version or "0", h.v)
      local info = (h.v and ("v" .. PSS:Safe(h.v)) or ("|cff9a9a9a" .. L("netVerUnknown") .. "|r")) .. (old and (" |cffff7a7a" .. L("netVerOld") .. "|r") or "")
      if not h.me then info = info .. "  ·  " .. Ago(h.t) end
      row.info:SetText(info)
      row:Show()
    else
      row:Hide()
    end
  end
  -- Feed.
  for _, b in ipairs(self.netFilters) do
    b:SetText(L("nf_f_" .. b.filter)); SetActive(b, st.filter == b.filter)
  end
  self.netMine:SetText(L("nf_mine")); SetActive(self.netMine, st.mine)
  local events = F and F:List(st.filter, st.mine) or {}
  st.offset = math.min(st.offset or 0, math.max(0, #events - NET_ROWS))
  for i, row in ipairs(self.netFeedRows) do
    local e = events[i + st.offset]
    if e then
      row.time:SetText(date and date("%H:%M", e.t) or "")
      row.text:SetText(self:NetEventText(e))
      row:Show()
    else
      row:Hide()
    end
  end
  Show(self.netEmpty, #events == 0)
  self.netEmpty:SetText(on and L("netFeedEmpty") or L("netFeedOffline"))
  local stats = F and F:Stats() or {sent = 0, recv = 0}
  local n, ok, mine = 0, 0, 0
  if F then n, ok, mine = F:QuestCounts() end
  self.netStats:SetText(string.format(L("netStatsLine"), stats.sent or 0, stats.recv or 0, n, ok, mine))
end

function UI:BuildQuests()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.quests = p
  local st = self.questState
  local function Reset()
    FauxScrollFrame_SetOffset(UI.qScroll, 0)
    local bar = UI.qScroll.ScrollBar or _G["PetSkillScoutQuestScrollScrollBar"]
    if bar then bar:SetValue(0) end
  end
  self.qModes = {}
  for i, m in ipairs({"hunter", "nearby", "log"}) do
    local b = MakeButton(p, "", 150, 32, function() st.mode = m; Reset(); UI:UpdateQuests() end, {size = 12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 154, 0)
    b.mode = m
    self.qModes[i] = b
  end
  self.qFilters = {}
  for i, f in ipairs({"ready", "all", "done"}) do
    local b = MakeButton(p, "", 150, 32, function() st.filter = f; Reset(); UI:UpdateQuests() end, {size = 12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", 484 + (i - 1) * 154, 0)
    b.filter = f
    self.qFilters[i] = b
  end
  self.qSummary = Label(p, "", 12, C.gold, BODY_W - 10, "LEFT", true)
  self.qSummary:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -42)

  self.qScroll = CreateFrame("ScrollFrame", "PetSkillScoutQuestScroll", p, "FauxScrollFrameTemplate")
  self.qScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -QUEST_TOP)
  self.qScroll:SetSize(BODY_W - 24, QUEST_ROWS * QUEST_ROW_H)
  self.qScroll:SetScript("OnVerticalScroll", function(f, offset)
    FauxScrollFrame_OnVerticalScroll(f, offset, QUEST_ROW_H, function() UI:UpdateQuests(true) end)
  end)
  self.qRows = {}
  local rw = BODY_W - 24
  for i = 1, QUEST_ROWS do
    local row = CreateFrame("Button", nil, p)
    row:SetSize(rw, QUEST_ROW_H - 6)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -QUEST_TOP - (i - 1) * QUEST_ROW_H)
    Panel(row, C.surface)
    row.bar = Solid(row, "OVERLAY", C.green, 1)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    row.lvl = Label(row, "", 16, C.gold, 40, "CENTER", true)
    row.lvl:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(38, 38)
    row.icon:SetPoint("LEFT", row, "LEFT", 54, 0)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints(row.icon)
    row.icon:SetScript("OnEnter", function(b)
      if not b.itemID then return QuestTooltip(b:GetParent()) end
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      if GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, b.itemID)
      else pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. b.itemID) end
      GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = Label(row, "", 14, C.cream, 380, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 104, -9)
    row.sub = Label(row, "", 11, C.muted, 380, "LEFT", true)
    row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 104, -31)
    row.item = Label(row, "", 13, C.cream, 250, "LEFT", true)
    row.item:SetPoint("TOPLEFT", row, "TOPLEFT", 496, -9)
    row.gain = Label(row, "", 11, C.muted, 250, "LEFT", true)
    row.gain:SetPoint("TOPLEFT", row, "TOPLEFT", 496, -31)
    row.status = Label(row, "", 13, C.cream, 170, "LEFT", true)
    row.status:SetPoint("TOPLEFT", row, "TOPLEFT", 756, -9)
    row.status2 = Label(row, "", 11, C.muted, 170, "LEFT", true)
    row.status2:SetPoint("TOPLEFT", row, "TOPLEFT", 756, -31)
    row.hide = IconButton(row, "Interface\\Icons\\Ability_EyeOfTheOwl", 28, function(b)
      local r = b:GetParent().data
      if not r then return end
      if r.e then PSS.Quests:SetHidden(r.e, not r.hidden)
      else PSS.Quests:SetHidden({key = "q" .. r.id}, not r.hidden) end
      UI.qList = nil
      UI:UpdateQuests()
    end, function(b)
      local r = b:GetParent().data
      return L(r and r.hidden and "qUnhide" or "qHide")
    end)
    row.hide:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.map = IconButton(row, TEX .. "Rare_map", 28, function(b)
      local r = b:GetParent().data
      if not r then return end
      if r.e then UI:OpenQuestMap(r.e, nil, r.target)
      else UI:OpenQuestMap(nil, r.r and r.r.m, r.target or (r.r and r.r.x and {name = r.r.n, mapID = r.r.m, points = {{r.r.x, r.r.y}}})) end
    end, function() return L("qMap") end)
    row.map:SetPoint("RIGHT", row.hide, "LEFT", -6, 0)
    row.arrow = IconButton(row, "Interface\\Minimap\\MinimapArrow", 28, function(b)
      local r = b:GetParent().data
      if not (r and PSS.Nav) then return end
      PSS.Nav:SetTarget(r.target)
    end, function() return L("qArrow") end)
    row.arrow:SetPoint("RIGHT", row.map, "LEFT", -6, 0)
    row:SetScript("OnEnter", QuestTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(r)
      if not (r.data and r.linkID and IsShiftKeyDown and IsShiftKeyDown()) then return end
      local _, link = PSS.Quests:ItemName(r.data.e or {}, r.linkID)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)
    ForwardWheel(row, self.qScroll, QUEST_ROW_H)
    self.qRows[i] = row
  end
  self.qEmpty = Label(p, "", 13, C.muted, 760, "LEFT")
  self.qEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -QUEST_TOP - 20)
  self.qHint = Label(p, "", 10, C.muted, BODY_W, "LEFT")
  self.qHint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 2, 0)
end

-- World map on a zone (not in combat: the map is a protected panel then).
-- target (optional): {name, mapID, points} - pinged on the map for a few seconds.
function UI:OpenQuestMap(e, mapID, target)
  if e then
    target = target or PSS.Quests:Target(e)
    -- The chain start may be in another zone than the last quest.
    mapID = (target and target.mapID) or PSS.Quests:ZoneMapID(e)
  end
  if not mapID then PSS:Print(string.format(L("qNoMap"), e and PSS.Quests:Info(e).zone or "?")); return end
  if InCombatLockdown and InCombatLockdown() then PSS:Print(L("qMapCombat")); return end
  if not PSS:OpenWorldMap(mapID) and target and PSS.Nav and PSS.Nav.SetTarget then pcall(PSS.Nav.SetTarget, PSS.Nav, target) end
  if target and target.mapID == mapID and PSS.Map and PSS.Map.Ping then pcall(PSS.Map.Ping, PSS.Map, target) end
end

local STATUS_COLOR = {done = "green", active = "gold", ready = "green", outgrown = "muted", soon = "cream", later = "muted", locked = "cream"}

-- Quest IDs in your quest log.
function UI:QuestLogIDs()
  local ids = {}
  local api = C_QuestLog
  if api and api.GetNumQuestLogEntries and api.GetInfo then
    local n = tonumber(PSS.IsSecret(api.GetNumQuestLogEntries()) and 0 or api.GetNumQuestLogEntries()) or 0
    for i = 1, n do
      local ok, info = pcall(api.GetInfo, i)
      if ok and type(info) == "table" and not info.isHeader and info.questID then ids[#ids + 1] = info.questID end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
      local r = {pcall(GetQuestLogTitle, i)}
      if r[1] and not r[5] and r[9] then ids[#ids + 1] = r[9] end
    end
  end
  return ids
end

-- Rows of the nearby / log modes.
function UI:QuestDBRows(mode, level)
  local W, Q = PSS.QuestWorth, PSS.Quests
  local out = {}
  if mode == "log" then
    for _, id in ipairs(self:QuestLogIDs()) do
      out[#out + 1] = {id = id, r = W:Record(id), rate = W:Rate(id, level), log = true}
    end
    local order = {great = 1, ok = 2, skip = 3}
    table.sort(out, function(a, b)
      if a.rate.verdict ~= b.rate.verdict then return order[a.rate.verdict] < order[b.rate.verdict] end
      return a.rate.ratio > b.rate.ratio
    end)
  else
    local mapID = PSS.Nav and PSS.Nav:PlayerPos() or (PSS.player and PSS.player.mapID)
    for _, x in ipairs(mapID and W:OnMap(mapID, level) or {}) do
      x.hidden = Q:Hidden({key = "q" .. x.id})
      if not x.hidden or self.questState.filter == "all" then out[#out + 1] = x end
    end
  end
  for _, x in ipairs(out) do
    local r = x.r
    if r and r.m and r.x then
      x.target = {name = W:NPCName(r.g) or W:Title(x.id), mapID = r.m, points = {{r.x, r.y}}}
      if x.log and r.ox and r.om then x.target = {name = W:Title(x.id), mapID = r.om, points = {{r.ox, r.oy}}} end
    end
  end
  return out
end

function UI:UpdateQuests(scrollOnly)
  if not self.qRows then return end
  local Q, W = PSS.Quests, PSS.QuestWorth
  local st = self.questState
  local level = Q:Level()
  local mode = st.mode or "hunter"
  if not scrollOnly or not self.qList or self.qListMode ~= mode then
    self.qList = mode == "hunter" and Q:Rows(st.filter, level) or self:QuestDBRows(mode, level)
    self.qListMode = mode
  end
  local list = self.qList
  local ready, done, total = Q:Counts(level)
  for _, b in ipairs(self.qModes) do
    local text = L("qMode_" .. b.mode)
    if b.mode == "hunter" and ready > 0 then text = text .. " (" .. ready .. ")" end
    b:SetText(text)
    SetActive(b, b.mode == mode)
  end
  for _, b in ipairs(self.qFilters) do
    b:SetText(L("qFilter_" .. b.filter))
    SetActive(b, b.filter == st.filter)
    Show(b, mode == "hunter")
  end
  if mode == "hunter" then
    self.qSummary:SetText(string.format(L("qSummary"), ready, done, total))
    self.qEmpty:SetText(L(st.filter == "done" and "qEmptyDone" or "qEmpty"))
    self.qHint:SetText(L("qHint"))
  else
    local great, skip = 0, 0
    for _, x in ipairs(list) do
      if x.rate.verdict == "great" then great = great + 1 elseif x.rate.verdict == "skip" then skip = skip + 1 end
    end
    self.qSummary:SetText(string.format(L(mode == "log" and "qwSummaryLog" or "qwSummaryNear"), #list, great, skip))
    self.qEmpty:SetText(L(mode == "log" and "qwEmptyLog" or "qwEmptyNear"))
    self.qHint:SetText(L("qwHint"))
  end
  Show(self.qEmpty, #list == 0)
  FauxScrollFrame_Update(self.qScroll, #list, QUEST_ROWS, QUEST_ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.qScroll)
  for i, row in ipairs(self.qRows) do
    local r = list[offset + i]
    row.data = r
    if not r then row:Hide()
    elseif r.e then self:FillHunterRow(row, r, level)
    else self:FillQuestRow(row, r, level) end
  end
end

function UI:FillHunterRow(row, r, level)
  local Q = PSS.Quests
  row:Show()
  local e, s = r.e, r.status
  local info = Q:Info(e)
  local min = Q:MinLevel(e)
  row.lvl:SetText(min)
  local tags = QuestTags(Q, e)
  local sub = Q:ZoneName(e)
  if info.npc then sub = info.npc .. "  ·  " .. sub end
  -- Earlier quests still to do: the first NPC of the chain and its zone.
  local first = e.quests and e.quests[1] and Q:FirstStep(e.quests[1])
  local fr = first and PSS.QuestDB[first]
  if fr then
    local who = (fr.g and PSS.QuestNPC and PSS.QuestNPC[fr.g]) or "?"
    local zi = C_Map and C_Map.GetMapInfo and select(2, pcall(C_Map.GetMapInfo, fr.m))
    local zone = type(zi) == "table" and zi.name or Q:ZoneName(e)
    sub = string.format(L("qStartAt"), who, zone, fr.n or "?")
  end
  if #tags > 0 then sub = sub .. "  ·  " .. table.concat(tags, ", ") end
  row.name:SetText(Q:Title(e))
  row.name:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
  row.sub:SetText(sub)
  local gain, bestId, known = Q:Gain(e)
  local id = bestId or (e.items and e.items[1])
  row.linkID = id
  row.icon.itemID = id
  row.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.icon.tex:SetDesaturated(false)
  row.icon.tex:SetVertexColor(1, 1, 1)
  row.icon.tex:SetTexture(id and Q:ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
  local name, _, q = Q:ItemName(e, id)
  local c = QUEST_QUALITY[q or 0] or C.cream
  local more = #(e.items or {}) - 1
  row.item:SetText(name .. (more > 0 and string.format("  " .. L("gearMore"), more) or ""))
  row.item:SetTextColor(c[1], c[2], c[3])
  local g
  if e.kind == "quiver" then g = L("qKindQuiver")
  elseif known then
    g = gain > 0 and ("|cff7ee0a3" .. string.format(L("qGain"), gain) .. "|r") or L("qNoGain")
  else g = L("qKindRanged") end
  if e.req and level < e.req then g = g .. "  ·  " .. string.format(L("qUseAt"), e.req) end
  row.gain:SetText(g)
  local s1, s2
  if s == "done" then s1 = L("qDone")
  elseif s == "active" then s1 = L("qActive")
  elseif s == "ready" then s1 = L("qReady")
  elseif s == "locked" then
    s1 = string.format(L(e.prereq or "qPrereq"), r.have or 0, r.need or 0)
    if e.prereqNote or e.note then s2 = L(e.prereqNote or e.note) end
  elseif s == "outgrown" then s1 = L("qOutgrown")
  elseif s == "soon" then s1 = string.format(L("qSoon"), min - level)
  else s1 = string.format(L("qFrom"), min) end
  if r.hidden then s2 = L("qHiddenMark") end
  local col = C[STATUS_COLOR[s] or "cream"] or C.cream
  row.status:SetText(s1)
  row.status:SetTextColor(col[1], col[2], col[3])
  row.status2:SetText(s2 or "")
  row.bar:SetVertexColor(C.green[1], C.green[2], C.green[3], 1)
  Show(row.bar, (s == "ready" or s == "active") and not r.hidden)
  row:SetAlpha((s == "done" or s == "outgrown" or r.hidden) and 0.6 or 1)
  Show(row.arrow, Q:Target(e) ~= nil)
  Show(row.hide, true)
  row.target = nil
  r.target = Q:Target(e)
end

function UI:FillQuestRow(row, x, level)
  local W, Q = PSS.QuestWorth, PSS.Quests
  row:Show()
  local rec, rate = x.r or {}, x.rate
  row.lvl:SetText(rec.l or "")
  row.name:SetText(W:Title(x.id))
  local col = W.COLORS[rate.verdict] or {1, 1, 1}
  row.name:SetTextColor(rate.verdict == "ok" and C.cream[1] or col[1], rate.verdict == "ok" and C.cream[2] or col[2], rate.verdict == "ok" and C.cream[3] or col[3])
  local sub = {}
  local npc = W:NPCName(rec.g)
  if npc then sub[#sub + 1] = npc end
  if rec.d then sub[#sub + 1] = L("qwDungeon") end
  if rec.b then sub[#sub + 1] = L("qwBreadcrumb") end
  row.sub:SetText(table.concat(sub, "  ·  "))
  -- Icon: the reward that is an upgrade, otherwise a quest mark in the verdict colour.
  row.icon.tex:SetDesaturated(false)
  if rate.gearItem then
    row.icon.itemID, row.linkID = rate.gearItem, rate.gearItem
    row.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon.tex:SetVertexColor(1, 1, 1)
    row.icon.tex:SetTexture(Q:ItemIcon(rate.gearItem))
  else
    row.icon.itemID, row.linkID = nil, nil
    row.icon.tex:SetTexCoord(0, 1, 0, 1)
    row.icon.tex:SetTexture(QUEST_ICON)
    if rate.verdict == "ok" then row.icon.tex:SetVertexColor(1, 1, 1)
    else row.icon.tex:SetDesaturated(true); row.icon.tex:SetVertexColor(col[1], col[2], col[3]) end
  end
  row.item:SetText(W:Summary(rate))
  row.item:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
  if rate.gearItem then
    local name = Q:ItemName({}, rate.gearItem)
    row.gain:SetText("|cff7ee0a3" .. string.format(L("qGain"), rate.gear) .. "|r  " .. name)
  else
    row.gain:SetText(string.format(L("qwRatio"), rate.ratio))
  end
  local status = L("qw_" .. rate.verdict)
  row.status:SetText(status)
  row.status:SetTextColor(col[1], col[2], col[3])
  row.status2:SetText(x.hidden and L("qHiddenMark") or (x.log and L("qActive") or ""))
  row.bar:SetVertexColor(col[1], col[2], col[3], 1)
  Show(row.bar, rate.verdict ~= "ok")
  row:SetAlpha((rate.verdict == "skip" or x.hidden) and 0.6 or 1)
  Show(row.arrow, x.target ~= nil)
  Show(row.hide, not x.log)
end

---------------------------------------------------------------------------
-- Collection: pet looks, achievements, rankings
---------------------------------------------------------------------------
local LOOK_COLS, LOOK_ROWS, LOOK_W, LOOK_H, LOOK_GAP = 5, 2, 200, 258, 10
local ACH_ROWS, ACH_ROW_H = 9, 60
local RANK_ROWS, RANK_ROW_H = 10, 50

local function ShortDate(t)
  if not t or not date then return "" end
  local ok, text = pcall(date, "%d.%m.%Y", t)
  return ok and text or ""
end

function UI:BuildCollection()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.collection = p
  local st = self.collectionState
  self.cModes = {}
  for i, mode in ipairs({"looks", "achievements", "ranking"}) do
    local b = MakeButton(p, "", 150, 32, function()
      st.mode = mode
      FauxScrollFrame_SetOffset(UI.cScroll, 0)
      local bar = UI.cScroll.ScrollBar or _G["PetSkillScoutCollectionScrollScrollBar"]
      if bar then bar:SetValue(0) end
      UI:UpdateCollection()
    end)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 156, 0)
    b.mode = mode
    self.cModes[i] = b
  end
  self.cSummary = Label(p, "", 13, C.cream, 520, "RIGHT", true)
  self.cSummary:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -2)
  self.cSub = Label(p, "", 11, C.muted, 520, "RIGHT", true)
  self.cSub:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -20)

  -- Looks filters
  local families = {"All"}
  for _, f in ipairs(PSS.Families) do table.insert(families, f) end
  self.cFamilyDD = MakeDropdown(p, families, function() return st.family end, 196,
    function(v) st.family = v; FauxScrollFrame_SetOffset(UI.cScroll, 0); UI:UpdateCollection() end,
    function(v) return L("family") .. ": " .. (v == "All" and L("all") or PSS:NameFamily(v)) end)
  self.cFamilyDD:SetPoint("TOPLEFT", p, "TOPLEFT", -16, -42)
  table.insert(self.dropdowns, self.cFamilyDD)
  self.cFilters = {}
  for i, f in ipairs({"all", "missing", "have"}) do
    local b = MakeButton(p, "", 116, 30, function()
      st.filter = f
      FauxScrollFrame_SetOffset(UI.cScroll, 0)
      UI:UpdateCollection()
    end, {size=12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", 214 + (i - 1) * 122, -42)
    b.filter = f
    self.cFilters[i] = b
  end
  self.cBar = Bar(p, 300, 6)
  self.cBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -58)
  -- Ranking scope
  self.cScopes = {}
  for i, scope in ipairs({"guild", "realm"}) do
    local b = MakeButton(p, "", 150, 30, function()
      st.scope = scope
      UI:UpdateCollection()
    end, {size=12})
    b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 156, -42)
    b.scope = scope
    self.cScopes[i] = b
  end

  self.cScroll = CreateFrame("ScrollFrame", "PetSkillScoutCollectionScroll", p, "FauxScrollFrameTemplate")
  self.cScroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84)
  self.cScroll:SetSize(BODY_W - 24, BODY_H - 90)
  self.cScroll:SetScript("OnVerticalScroll", function(f, offset)
    local h = UI.collectionState.mode == "looks" and (LOOK_H + LOOK_GAP) or
      (UI.collectionState.mode == "achievements" and ACH_ROW_H or RANK_ROW_H)
    FauxScrollFrame_OnVerticalScroll(f, offset, h, function() UI:UpdateCollection(true) end)
  end)

  -- Look tiles
  self.cTiles = {}
  for row = 1, LOOK_ROWS do
    for col = 1, LOOK_COLS do
      local tile = CreateFrame("Frame", nil, p)
      tile:SetSize(LOOK_W, LOOK_H)
      tile:SetPoint("TOPLEFT", p, "TOPLEFT", (col - 1) * (LOOK_W + LOOK_GAP), -84 - (row - 1) * (LOOK_H + LOOK_GAP))
      Panel(tile, C.surface)
      tile.view = Viewport(tile, LOOK_W - 16, 140)
      tile.view:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -8)
      tile.name = Label(tile, "", 13, C.cream, LOOK_W - 20, "LEFT", true)
      tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -156)
      tile.sub = Label(tile, "", 11, C.muted, LOOK_W - 20, "LEFT", true)
      tile.sub:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -176)
      tile.where = Label(tile, "", 10, C.muted, LOOK_W - 20, "LEFT", true)
      tile.where:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -193)
      tile.badge = Badge(tile)
      tile.badge:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 10, 14)
      tile.arrow = IconButton(tile, "Interface\\Minimap\\MinimapArrow", 28, function()
        local look = tile.look
        local b = look and PSS.Collection:NearestBeast(look)
        if b and PSS.Nav then PSS.Nav:SetTarget(PSS.Nav:TargetFromAtlas(b.npcID) or PSS.Nav:TargetFromBeast(b)) end
      end, function() return L("arrowButton") end)
      tile.arrow:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -10, 10)
      tile.find = IconButton(tile, "Interface\\Icons\\INV_Misc_Spyglass_02", 28, function()
        local look = tile.look
        if look and look.beasts[1] then
          UI.bSelected = look.beasts[1].npcID
          UI.bSearch.edit:SetText(look.beasts[1].name)
          UI:ShowView("beasts")
        end
      end, function() return L("lookFind") end)
      tile.find:SetPoint("RIGHT", tile.arrow, "LEFT", -6, 0)
      tile.owners = Label(tile, "", 10, {0.56, 0.78, 1}, LOOK_W - 20, "LEFT", true)
      tile.owners:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -209)
      tile.who = IconButton(tile, "Interface\\Icons\\INV_Misc_GroupLooking", 28, function(b)
        if tile.look then UI:ShowOwners(tile.look, b) end
      end, function() return L("showcaseWho") end)
      tile.who:SetPoint("RIGHT", tile.find, "LEFT", -6, 0)
      tile:EnableMouse(true)
      SetTip(tile, function()
        local look = tile.look
        if not look then return nil end
        local lines = {look.name}
        for i, b in ipairs(look.beasts) do
          if i > 8 then table.insert(lines, "...") break end
          table.insert(lines, b.name .. "  (" .. LevelText(b) .. ", " .. (b.zone or "?") .. ")")
        end
        return table.concat(lines, "\n")
      end)
      ForwardWheel(tile, self.cScroll, LOOK_H + LOOK_GAP)
      table.insert(self.cTiles, tile)
    end
  end
  -- Achievement rows
  self.cAch = {}
  for i = 1, ACH_ROWS do
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(BODY_W - 24, ACH_ROW_H - 6)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84 - (i - 1) * ACH_ROW_H)
    Panel(row, C.surface)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(38, 38)
    row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = Label(row, "", 14, C.cream, 420, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 60, -9)
    row.desc = Label(row, "", 11, C.muted, 420, "LEFT", true)
    row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", 60, -31)
    row.bar = Bar(row, 260, 8)
    row.bar:SetPoint("LEFT", row, "LEFT", 520, -6)
    row.value = Label(row, "", 11, C.muted, 260, "LEFT", true)
    row.value:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", 0, 4)
    row.points = Label(row, "", 16, C.gold, 80, "RIGHT", true)
    row.points:SetPoint("RIGHT", row, "RIGHT", -14, 6)
    row.when = Label(row, "", 10, C.muted, 120, "RIGHT", true)
    row.when:SetPoint("RIGHT", row, "RIGHT", -14, -12)
    ForwardWheel(row, self.cScroll, ACH_ROW_H)
    self.cAch[i] = row
  end
  -- Ranking rows
  self.cRank = {}
  for i = 1, RANK_ROWS do
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(BODY_W - 24, RANK_ROW_H - 6)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -84 - (i - 1) * RANK_ROW_H)
    Panel(row, C.surface)
    row.bar = Solid(row, "OVERLAY", C.gold, 1)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bar:SetWidth(3)
    row.pos = Label(row, "", 16, C.gold, 44, "CENTER", true)
    row.pos:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.dot = Dot(row, 10)
    row.dot:SetPoint("LEFT", row, "LEFT", 60, 0)
    row.name = Label(row, "", 14, C.cream, 300, "LEFT", true)
    row.name:SetPoint("LEFT", row, "LEFT", 80, 0)
    row.score = Label(row, "", 14, C.gold, 140, "RIGHT", true)
    row.score:SetPoint("LEFT", row, "LEFT", 400, 0)
    row.looks = Label(row, "", 12, C.muted, 160, "RIGHT", true)
    row.looks:SetPoint("LEFT", row, "LEFT", 560, 0)
    row.rares = Label(row, "", 12, C.muted, 150, "RIGHT", true)
    row.rares:SetPoint("LEFT", row, "LEFT", 720, 0)
    row.fams = Label(row, "", 12, C.muted, 150, "RIGHT", true)
    row.fams:SetPoint("LEFT", row, "LEFT", 870, 0)
    ForwardWheel(row, self.cScroll, RANK_ROW_H)
    self.cRank[i] = row
  end
  self.cEmpty = Label(p, "", 13, C.muted, 760, "LEFT")
  self.cEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -100)
end

function UI:UpdateCollection(scrollOnly)
  if not self.cTiles then return end
  local st = self.collectionState
  local mode = st.mode
  local Col, Ach = PSS.Collection, PSS.Achieve
  for _, b in ipairs(self.cModes) do b:SetText(L("col_" .. b.mode)); SetActive(b, b.mode == mode) end
  for _, b in ipairs(self.cFilters) do b:SetText(L("colFilter_" .. b.filter)); SetActive(b, b.filter == st.filter); Show(b, mode == "looks") end
  for _, b in ipairs(self.cScopes) do b:SetText(L("rank_" .. b.scope)); SetActive(b, b.scope == st.scope); Show(b, mode == "ranking") end
  Show(self.cFamilyDD, mode == "looks")
  Show(self.cBar, mode ~= "ranking")
  for _, t in ipairs(self.cTiles) do Show(t, false) end
  for _, r in ipairs(self.cAch) do Show(r, false) end
  for _, r in ipairs(self.cRank) do Show(r, false) end
  Show(self.cEmpty, false)
  local score = Ach and Ach:Score() or 0
  if mode == "looks" then
    self.cFamilyDD:Sync()
    Col:Build()
    local have, total = Col:Counts()
    self.cSummary:SetText(string.format(L("colLooksSummary"), have, total))
    self.cSub:SetText(string.format(L("colFamiliesSummary"), Col:FamiliesTamed(), Col:FamilyTotal()))
    self.cBar:SetFraction(total > 0 and have / total or 0, C.gold)
    local list = {}
    for _, look in ipairs(Col.looks) do
      local ok = st.family == "All" or look.family == st.family
      local got = Col:IsCollected(look)
      if ok and st.filter == "missing" and got then ok = false end
      if ok and st.filter == "have" and not got then ok = false end
      if ok then table.insert(list, look) end
    end
    local rowsTotal = math.ceil(#list / LOOK_COLS)
    FauxScrollFrame_Update(self.cScroll, rowsTotal, LOOK_ROWS, LOOK_H + LOOK_GAP)
    local offset = FauxScrollFrame_GetOffset(self.cScroll) * LOOK_COLS
    for i, tile in ipairs(self.cTiles) do
      local look = list[i + offset]
      tile.look = look
      if look then
        local got = Col:IsCollected(look)
        tile.view:SetSubject({display = look.display, npc = look.npc}, FamilyIcon(look.family))
        tile.name:SetText(look.name)
        local lv = look.minLevel and (look.maxLevel and look.maxLevel ~= look.minLevel and (look.minLevel .. "-" .. look.maxLevel) or tostring(look.minLevel)) or "?"
        tile.sub:SetText(PSS:NameFamily(look.family) .. "  ·  " .. L("level") .. " " .. lv)
        local zones, seen = {}, {}
        for _, b in ipairs(look.beasts) do
          if b.zone and not seen[b.zone] then seen[b.zone] = true; table.insert(zones, b.zone) end
        end
        local where = string.format(L("lookBeasts"), #look.beasts)
        if zones[1] then where = where .. "  ·  " .. zones[1] .. (#zones > 1 and (" +" .. (#zones - 1)) or "") end
        tile.where:SetText(where)
        if got then tile.badge:Set("tamed", L("lookHave"))
        elseif look.onlyRare then tile.badge:Set("want", L("lookRare"))
        elseif look.new then tile.badge:Set("new", L("rareNew"))
        else tile.badge:Set("none", L("lookMissing")) end
        tile:SetAlpha(got and 1 or 0.92)
        SetEdgeColor(tile.pssEdges, got and STATUS.tamed.edge or (look.onlyRare and STATUS.want.edge) or C.border, 1)
        Show(tile.arrow, look.beasts[1] ~= nil)
        local owners = PSS.Showcase and PSS.Showcase:Owners(look.id) or {}
        tile.owners:SetText(#owners > 0 and string.format(L("showcaseCount"), #owners) or "")
        Show(tile.who, #owners > 0)
        tile:Show()
      end
    end
    self.cEmpty:SetText(L("colEmpty"))
    Show(self.cEmpty, #list == 0)
  elseif mode == "achievements" then
    local list = Ach and Ach.LIST or {}
    self.cSummary:SetText(string.format(L("achSummary"), score))
    self.cSub:SetText(string.format(L("achCount"), Ach and Ach:Unlocked() or 0, #list))
    self.cBar:SetFraction(#list > 0 and (Ach:Unlocked() / #list) or 0, C.gold)
    -- Unlocked last, the closest ones first.
    local sorted = {}
    for _, def in ipairs(list) do
      local v, g, done = Ach:Progress(def)
      table.insert(sorted, {def = def, v = v, g = g, done = done, frac = math.min(1, v / g)})
    end
    table.sort(sorted, function(a, b)
      if (a.done ~= nil) ~= (b.done ~= nil) then return a.done == nil end
      if a.frac ~= b.frac then return a.frac > b.frac end
      return a.def[3] < b.def[3]
    end)
    FauxScrollFrame_Update(self.cScroll, #sorted, ACH_ROWS, ACH_ROW_H)
    local offset = FauxScrollFrame_GetOffset(self.cScroll)
    for i, row in ipairs(self.cAch) do
      local a = sorted[i + offset]
      if a then
        row.icon:SetTexture("Interface\\Icons\\" .. a.def[2])
        if row.icon.SetDesaturated then row.icon:SetDesaturated(a.done == nil) end
        row.name:SetText(L("ach_" .. a.def[1]))
        row.desc:SetText(string.format(L("achd_" .. a.def[1]), a.g))
        row.bar:SetFraction(a.frac, a.done and STATUS.tamed.edge or C.gold)
        row.value:SetText(string.format("%d / %d", math.min(a.v, a.g), a.g))
        row.points:SetText(tostring(a.def[3]))
        row.when:SetText(a.done and ShortDate(a.done) or "")
        row:SetAlpha(a.done and 1 or 0.85)
        row:Show()
      end
    end
  else
    local N = PSS.Net
    local list = N and N:Ranking(st.scope) or {}
    self.cSummary:SetText(string.format(L("rankOnline"), N and N:OnlineCount() or 1))
    self.cSub:SetText(string.format(L("achSummary"), score))
    FauxScrollFrame_Update(self.cScroll, #list, RANK_ROWS, RANK_ROW_H)
    local offset = FauxScrollFrame_GetOffset(self.cScroll)
    for i, row in ipairs(self.cRank) do
      local r = list[i + offset]
      if r then
        row.pos:SetText(tostring(i + offset))
        row.name:SetText(r.me and (r.name .. "  (" .. L("queueYou") .. ")") or r.name)
        row.score:SetText(string.format(L("rankScore"), r.score))
        row.looks:SetText(string.format(L("rankLooks"), r.skins))
        row.rares:SetText(string.format(L("rankRares"), r.rares))
        row.fams:SetText(string.format(L("rankFams"), r.fams))
        SetDot(row.dot, r.online and "next" or "none")
        Show(row.bar, r.me)
        row:Show()
      end
    end
    self.cEmpty:SetText(L(st.scope == "guild" and "rankEmptyGuild" or "rankEmptyRealm"))
    Show(self.cEmpty, #list <= 1)
    if #list <= 1 then self.cEmpty:ClearAllPoints(); self.cEmpty:SetPoint("TOPLEFT", self.views.collection, "TOPLEFT", 10, -150)
    else self.cEmpty:ClearAllPoints(); self.cEmpty:SetPoint("TOPLEFT", self.views.collection, "TOPLEFT", 10, -100) end
  end
end

-- Popup with the hunters who have a look; click a name for their card.
local OWNER_LINES = 12
function UI:ShowOwners(look, anchor)
  local pop = self.ownersPopup
  if not pop then
    pop = CreateFrame("Frame", nil, frame)
    pop:SetFrameStrata("FULLSCREEN_DIALOG")
    pop:SetSize(220, 40)
    pop:EnableMouse(true)
    Panel(pop, C.deep)
    pop.title = Label(pop, "", 12, C.gold, 196, "LEFT", true)
    pop.title:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)
    pop.close = MakeButton(pop, "X", 20, 20, function() pop:Hide() end, {size=10})
    pop.close:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -4, -4)
    pop.lines = {}
    for i = 1, OWNER_LINES do
      local b = CreateFrame("Button", nil, pop)
      b:SetSize(200, 18)
      b:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -26 - (i - 1) * 19)
      b.text = Label(b, "", 12, C.cream, 200, "LEFT", true)
      b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
      local hl = Solid(b, "HIGHLIGHT", C.gold, 0.12)
      hl:SetAllPoints(b)
      b:SetScript("OnClick", function(btn)
        if btn.owner and PSS.Showcase then PSS.Showcase:RequestCard(btn.owner, pop.lookId) end
        pop:Hide()
      end)
      pop.lines[i] = b
    end
    self.ownersPopup = pop
  end
  local owners = PSS.Showcase and PSS.Showcase:Owners(look.id) or {}
  pop.lookId = look.id
  pop.title:SetText(string.format(L("showcaseTitle"), look.name))
  for i, b in ipairs(pop.lines) do
    local o = owners[i]
    b.owner = o and o.name
    if o then
      local tag = o.active and ("  |cff8fe0a0" .. L("showcaseActive") .. "|r") or ""
      b.text:SetText((o.online and "|cff7ee0a3●|r " or "|cff777777●|r ") .. o.name .. tag)
      b:Show()
    else
      b:Hide()
    end
  end
  pop:SetHeight(34 + math.min(#owners, OWNER_LINES) * 19)
  pop:ClearAllPoints()
  pop:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
  pop:Show()
end

---------------------------------------------------------------------------
-- Pet card / passport window (own pet or a card received from a link)
---------------------------------------------------------------------------
local CARD_WIN_W, CARD_WIN_H = 640, 400

function UI:BuildCard()
  if self.card then return self.card end
  local f = CreateFrame("Frame", "PetSkillScoutCard", UIParent)
  f:SetSize(CARD_WIN_W, CARD_WIN_H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(50)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) s:StartMoving() end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "PetSkillScoutCard") end
  local bg = Solid(f, "BACKGROUND", C.background)
  bg:SetAllPoints(f)
  f.edges = Border(f, C.gold, 0.9, 2)
  local glow = Solid(f, "BACKGROUND", C.gold, 0.06, 1)
  glow:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  glow:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  glow:SetHeight(48)
  f.logo = f:CreateTexture(nil, "ARTWORK")
  f.logo:SetTexture(TEX .. "PetSkillScoutLogo")
  f.logo:SetSize(30, 30)
  f.logo:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -9)
  f.kicker = Label(f, "", 12, C.gold, 360, "LEFT", true)
  f.kicker:SetPoint("LEFT", f.logo, "RIGHT", 10, 0)
  f.close = MakeButton(f, "X", 30, 30, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -9)
  f.shot = MakeButton(f, "", 130, 30, function() UI:CardScreenshot() end, {size=12})
  f.shot:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
  f.share = MakeButton(f, "", 130, 30, function() if PSS.PetLink then PSS.PetLink:Share() end end, {size=12})
  f.share:SetPoint("RIGHT", f.shot, "LEFT", -8, 0)
  f.view = Viewport(f, 250, 300, "card")
  f.view:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60)
  local x = 286
  f.name = Label(f, "", 28, C.cream, CARD_WIN_W - x - 20, "LEFT", true)
  f.name:SetPoint("TOPLEFT", f, "TOPLEFT", x, -62)
  f.sub = Label(f, "", 14, C.muted, CARD_WIN_W - x - 20, "LEFT", true)
  f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", x, -100)
  f.lines = {}
  for i = 1, 3 do
    local l = Label(f, "", 12, C.cream, CARD_WIN_W - x - 20, "LEFT", true)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", x, -126 - (i - 1) * 20)
    f.lines[i] = l
  end
  f.skills = {}
  for i = 1, 6 do
    local s = {}
    s.name = Label(f, "", 12, C.cream, 150, "LEFT", true)
    s.name:SetPoint("TOPLEFT", f, "TOPLEFT", x, -196 - (i - 1) * 22)
    s.dots = {}
    for j = 1, 8 do
      local d = Dot(f, 10)
      d:SetPoint("TOPLEFT", f, "TOPLEFT", x + 160 + (j - 1) * 14, -199 - (i - 1) * 22)
      s.dots[j] = d
    end
    f.skills[i] = s
  end
  f.status = Label(f, "", 13, C.muted, CARD_WIN_W - x - 20, "LEFT")
  f.status:SetPoint("TOPLEFT", f, "TOPLEFT", x, -200)
  local line = Solid(f, "ARTWORK", C.gold, 0.4)
  line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
  line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 40)
  line:SetHeight(1)
  f.footer = Label(f, "", 12, C.muted, CARD_WIN_W - 200, "LEFT", true)
  f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
  f.brand = Label(f, "PetSkillScout", 12, C.gold, 170, "RIGHT", true)
  f.brand:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  f:Hide()
  self.card = f
  return f
end

function UI:ShowCard(card)
  if not card then return end
  local f = self:BuildCard()
  f.data = card
  f.kicker:SetText(L(card.own and "cardOwnTitle" or "cardTitle"))
  f.shot:SetText(L("cardShot"))
  f.share:SetText(L("cardShare"))
  Show(f.share, card.own)
  f.name:SetText(card.name or "?")
  local subParts = {}
  if card.family then table.insert(subParts, PSS:NameFamily(card.family)) end
  if card.level then table.insert(subParts, L("level") .. " " .. card.level) end
  f.sub:SetText(table.concat(subParts, "  ·  "))
  f.view:SetSubject(card.own and {unit = "pet"} or {display = card.display, npc = card.npc}, FamilyIcon(card.family), true)
  local lines = {}
  if card.first or card.zone then
    local when = card.first and ShortDate(card.first) or nil
    if card.tamed then table.insert(lines, string.format(L("cardTamed"), (when or "?") .. (card.zone and (", " .. card.zone) or "")))
    elseif card.zone then table.insert(lines, string.format(L("cardWith"), card.zone)) end
  end
  if card.days then table.insert(lines, string.format(L("cardDays"), card.days)) end
  if card.loyalty then table.insert(lines, L("loyalty") .. ": " .. card.loyalty) end
  for i, l in ipairs(f.lines) do l:SetText(lines[i] or "") end
  local skills = card.skills or {}
  for i, s in ipairs(f.skills) do
    local sk = skills[i]
    if sk then
      s.name:SetText(PSS:NameAbility(sk.key))
      local max = PSS.Ranks[sk.key] and #PSS.Ranks[sk.key] or (sk.rank or 1)
      for j, d in ipairs(s.dots) do
        Show(d, j <= math.min(8, max))
        SetDot(d, j <= (sk.rank or 0) and "have" or "none")
      end
      s.name:Show()
    else
      s.name:Hide()
      for _, d in ipairs(s.dots) do d:Hide() end
    end
  end
  if card.loading then f.status:SetText(L("cardLoading"))
  elseif card.failed then f.status:SetText(L("cardFailed"))
  else f.status:SetText("") end
  Show(f.status, card.loading or card.failed)
  local total = PSS.Collection and select(2, PSS.Collection:Counts()) or 0
  if card.loading or card.failed then
    f.footer:SetText(string.format(L("cardHunter"), card.hunter or "?"))
  else
    f.footer:SetText(string.format(L("cardFooter"), card.hunter or "?", card.looks or 0, total, card.rares or 0, card.score or 0))
  end
  f:Show()
end

-- Screenshot mode: buttons hidden for a few seconds so the player can press
-- the screenshot key (taking it from addon code is not allowed everywhere).
function UI:CardScreenshot()
  local f = self.card
  if not f then return end
  f.close:Hide(); f.shot:Hide(); f.share:Hide()
  PSS:Print(L("cardShotHint"))
  local t = 0
  f:SetScript("OnUpdate", function(s, elapsed)
    t = t + (elapsed or 0)
    if t > 5 then
      s:SetScript("OnUpdate", nil)
      s.close:Show(); s.shot:Show(); Show(s.share, s.data and s.data.own)
    end
  end)
end

function UI:ShowPassport()
  local card = PSS.PetLink and PSS.PetLink:OwnCard()
  if not card then PSS:Print(L("petSummon")) return end
  self:ShowCard(card)
end

---------------------------------------------------------------------------
-- My Pet: pet card, skills with rank pips, stable
---------------------------------------------------------------------------
local CARD_W, SKILL_ROWS = 340, 8

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

function UI:BuildPet()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.pet = p
  self.petPanel = p
  -- Card
  local card = CreateFrame("Frame", nil, p)
  card:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  card:SetSize(CARD_W, BODY_H)
  Panel(card, C.surface)
  self.pCard = card
  card.view = Viewport(card, CARD_W - 28, 214, "pet")
  card.view:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -14)
  card.passport = IconButton(card, "Interface\\Icons\\INV_Misc_Book_09", 30, function() UI:ShowPassport() end,
    function() return L("cardOwnTitle") end)
  card.passport:SetPoint("TOPRIGHT", card.view, "TOPRIGHT", -6, -6)
  card.share = IconButton(card, "Interface\\Icons\\INV_Letter_15", 30, function()
    if PSS.PetLink then PSS.PetLink:Share() end
  end, function() return L("cardShareTip") end)
  card.share:SetPoint("RIGHT", card.passport, "LEFT", -6, 0)
  card.passport:SetFrameLevel(card.view:GetFrameLevel() + 8)
  card.share:SetFrameLevel(card.view:GetFrameLevel() + 8)
  card.name = Label(card, "", 22, C.cream, CARD_W - 28, "LEFT", true)
  card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -240)
  card.sub = Label(card, "", 12, C.muted, CARD_W - 28, "LEFT")
  card.sub:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -270)
  card.meters = {}
  for i = 1, 5 do
    local m = {}
    local y = -298 - (i - 1) * 44
    m.key = Label(card, "", 12, C.cream, 150, "LEFT", true)
    m.key:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y)
    m.value = Label(card, "", 12, C.muted, 160, "RIGHT", true)
    m.value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, y)
    m.bar = Bar(card, CARD_W - 28, 8)
    m.bar:SetPoint("TOPLEFT", card, "TOPLEFT", 14, y - 20)
    card.meters[i] = m
  end
  -- Food box with the Feed button slot
  local food = CreateFrame("Frame", nil, card)
  food:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 14)
  food:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 14)
  food:SetHeight(64)
  local fbg = Solid(food, "BACKGROUND", C.deep, 0.85)
  fbg:SetAllPoints(food)
  Border(food, C.border)
  food.icon = food:CreateTexture(nil, "ARTWORK")
  food.icon:SetSize(40, 40)
  food.icon:SetPoint("LEFT", food, "LEFT", 10, 0)
  food.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  food.count = Label(food, "", 12, C.gold, 40, "RIGHT", true)
  food.count:SetPoint("BOTTOMRIGHT", food.icon, "BOTTOMRIGHT", 2, -2)
  food.name = Label(food, "", 13, C.cream, 150, "LEFT", true)
  food.name:SetPoint("TOPLEFT", food, "TOPLEFT", 60, -14)
  food.diet = Label(food, "", 10, C.muted, 150, "LEFT", true)
  food.diet:SetPoint("TOPLEFT", food, "TOPLEFT", 60, -34)
  food.slot = CreateFrame("Frame", nil, food)
  food.slot:SetSize(104, 34)
  food.slot:SetPoint("RIGHT", food, "RIGHT", -10, 0)
  food.slotText = Label(food.slot, "", 11, C.muted, 104, "CENTER")
  food.slotText:SetPoint("CENTER", food.slot, "CENTER", 0, 0)
  card.food = food
  self.feedSlot = food.slot
  card.none = Label(card, "", 13, C.muted, CARD_W - 28, "LEFT")
  card.none:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -300)
  -- Ammo line: count and nearest place to buy (only for bows, guns, crossbows).
  local ammo = CreateFrame("Frame", nil, card)
  ammo:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -512)
  ammo:SetSize(CARD_W - 28, 34)
  ammo.icon = ammo:CreateTexture(nil, "ARTWORK")
  ammo.icon:SetSize(26, 26)
  ammo.icon:SetPoint("LEFT", ammo, "LEFT", 0, 0)
  ammo.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ammo.count = Label(ammo, "", 12, C.cream, CARD_W - 110, "LEFT", true)
  ammo.count:SetPoint("TOPLEFT", ammo, "TOPLEFT", 34, -2)
  ammo.place = Label(ammo, "", 10, C.muted, CARD_W - 110, "LEFT", true)
  ammo.place:SetPoint("TOPLEFT", ammo, "TOPLEFT", 34, -19)
  ammo.go = IconButton(ammo, "Interface\\Minimap\\MinimapArrow", 28, function()
    if PSS.Ammo then PSS.Ammo:Go() end
  end, function() return L("ammoGoTip") end)
  ammo.go:SetPoint("RIGHT", ammo, "RIGHT", 0, 0)
  card.ammo = ammo

  -- Skills
  local right = CreateFrame("Frame", nil, p)
  right:SetPoint("TOPLEFT", p, "TOPLEFT", CARD_W + 16, 0)
  right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  self.pRight = right
  local rw = BODY_W - CARD_W - 16
  self.pSkillsTitle = Label(right, "", 12, C.muted, 380, "LEFT", true)
  self.pSkillsTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -2)
  self.pLegend = Label(right, "", 11, C.muted, 320, "RIGHT", true)
  self.pLegend:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -2)
  self.pSkillRows = {}
  for i = 1, SKILL_ROWS do
    local row = CreateFrame("Frame", nil, right)
    row:SetSize(rw, 48)
    row:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -24 - (i - 1) * 54)
    Panel(row, C.surface)
    row.name = Label(row, "", 14, C.cream, 160, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -7)
    row.sub = Label(row, "", 10, C.muted, 160, "LEFT", true)
    row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -27)
    row.dots = {}
    for j = 1, 10 do
      local dot = Dot(row, 11)
      dot:SetPoint("LEFT", row, "LEFT", 186 + (j - 1) * 16, 0)
      row.dots[j] = dot
    end
    row.note = Label(row, "", 11, C.muted, 250, "RIGHT", true)
    row.note:SetPoint("RIGHT", row, "RIGHT", -128, 0)
    row.find = MakeButton(row, "", 108, 30, function(b) if b.ability then SearchFor(b.ability, b.rank) end end)
    row.find:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    self.pSkillRows[i] = row
  end
  self.pSkillNote = Label(right, "", 12, C.muted, rw - 20)
  self.pSkillNote:SetPoint("TOPLEFT", right, "TOPLEFT", 6, -34)
  self:BuildPlanner(right)

  -- Stable
  self.pStableTitle = Label(right, "", 12, C.muted, 200, "LEFT", true)
  self.pStableTitle:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 106)
  self.pStableInfo = Label(right, "", 11, C.muted, 300, "LEFT", true)
  self.pStableInfo:SetPoint("LEFT", self.pStableTitle, "RIGHT", 10, 0)
  self.pStableScan = MakeButton(right, "", 150, 28, function()
    if PSS.Stable then PSS.Stable:Scan(); PSS:Print(PSS.Stable.status) end
    UI:RefreshPet()
  end)
  self.pStableScan:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 100)
  self.pStable = {}
  local cw = math.floor((rw - 20) / 3)
  for i = 1, 3 do
    local c = CreateFrame("Button", nil, right)
    c:SetSize(cw, 84)
    c:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", (i - 1) * (cw + 10), 0)
    Panel(c, C.surface)
    local hover = Solid(c, "HIGHLIGHT", C.gold, 0.08)
    hover:SetAllPoints(c)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(44, 44)
    c.icon:SetPoint("LEFT", c, "LEFT", 12, 0)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.name = Label(c, "", 14, C.cream, cw - 76, "LEFT", true)
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -16)
    c.sub = Label(c, "", 11, C.muted, cw - 76, "LEFT", true)
    c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -38)
    c.skills = Label(c, "", 10, C.muted, cw - 76, "LEFT", true)
    c.skills:SetPoint("TOPLEFT", c, "TOPLEFT", 66, -56)
    c.empty = Label(c, "", 12, C.muted, cw - 20, "CENTER")
    c.empty:SetPoint("CENTER", c, "CENTER", 0, 0)
    c:SetScript("OnClick", function(btn)
      if btn.entry and PSS.ModelPreview and PSS.ModelPreview.ShowStable then
        if PSS.Stable then PSS.Stable.selected = btn.index end
        PSS.ModelPreview:ShowStable(btn.entry)
      end
    end)
    self.pStable[i] = c
  end
end

local function SkillSource(key)
  local learn = PSS.Abilities[key] and PSS.Abilities[key].learn
  if learn == "family" then return L("learnSrcFamily"), learn end
  if learn == "trainer" then return L("learnSrcTrainer"), learn end
  return L("learnSrcBeast"), "beast"
end

function UI:FillSkillRow(row, key, have, petLevel, freeSlot)
  local source, learn = SkillSource(key)
  row.name:SetText(PSS:NameAbility(key))
  row.sub:SetText(freeSlot and (source .. "  ·  " .. L("freeSlot")) or source)
  local total = math.min(10, MaxRank(key, have or 1))
  local nextRank
  if have then
    for _, r in ipairs(RanksForAbility(key)) do if r > have then nextRank = r break end end
  else
    nextRank = nil
  end
  local isNew = have == 0
  if isNew then nextRank = RanksForAbility(key)[1] or 1 end
  for j, dot in ipairs(row.dots) do
    if j <= total then
      local state = "none"
      if have and j <= have then state = "have" elseif nextRank and j == nextRank then state = "next" end
      SetDot(dot, state)
      dot:Show()
    else
      dot:Hide()
    end
  end
  local note, color = L("rankUnknown"), C.muted
  if have then
    if nextRank then
      local meta = PSS.Ranks[key] and PSS.Ranks[key][nextRank]
      local need = meta and meta.petLevel
      if need and petLevel and petLevel < need then
        note = isNew and string.format(L("learnAt"), need) or string.format(L("nextRankAt"), nextRank, need)
      else
        note, color = isNew and L("learnNow") or string.format(L("nextRankNow"), nextRank), C.green
      end
    else
      note = L("maxRank")
    end
  end
  row.note:SetText(note)
  row.note:SetTextColor(color[1], color[2], color[3])
  local findable = learn == "beast" and nextRank ~= nil
  row.find:SetText(L("whereToLearn"))
  row.find.ability, row.find.rank = key, isNew and "All" or nextRank
  Show(row.find, findable)
  row:Show()
end

-- Runs one part of a view; an error there is reported once in chat and does
-- not stop the other parts from updating.
local reportedErrors = {}
---------------------------------------------------------------------------
-- Training point planner (inside the My Pet tab)
---------------------------------------------------------------------------
local PLAN_ROWS, PLAN_PIPS = 7, 8

local function Pip(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(15, 15)
  b.ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
  b.ring:SetTexture(CIRCLE)
  b.ring:SetAllPoints(b)
  b.core = b:CreateTexture(nil, "ARTWORK", nil, 2)
  b.core:SetTexture(CIRCLE)
  b.core:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.core:SetSize(11, 11)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(CIRCLE)
  hl:SetAllPoints(b)
  hl:SetVertexColor(1, 1, 1, 0.25)
  b:SetScript("OnClick", onClick)
  return b
end

function UI:BuildPlanner(right)
  local rw = BODY_W - CARD_W - 16
  self.pPlanBtn = MakeButton(right, "", 170, 22, function()
    UI.petPlanner = not UI.petPlanner
    UI:RefreshPet(true)
  end, {size=11})
  self.pPlanBtn:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, 0)
  self.pLegend:ClearAllPoints()
  self.pLegend:SetPoint("RIGHT", self.pPlanBtn, "LEFT", -10, 0)
  self.pLegend:SetWidth(240)
  local f = CreateFrame("Frame", nil, right)
  f:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -28)
  f:SetSize(rw, 470)
  self.pPlan = f
  f.tp = Label(f, "", 13, C.cream, 440, "LEFT", true)
  f.tp:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)
  f.bar = Bar(f, 240, 8)
  f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -9)
  f.presets = {}
  for i, role in ipairs({"solo", "dungeon", "pvp", "current", "clear"}) do
    local b = MakeButton(f, "", 132, 28, function()
      local P = PSS.Planner
      if role == "current" then
        local cur = P:Current()
        local copy = {}
        for k, v in pairs(cur) do copy[k] = v end
        P:SetPlan(copy)
      elseif role == "clear" then P:SetPlan({})
      else P:Preset(role) end
      UI:RefreshPlanner()
    end, {size=12})
    b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * 138, -30)
    b.role = role
    f.presets[i] = b
  end
  f.rows = {}
  for i = 1, PLAN_ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(rw, 44)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -68 - (i - 1) * 50)
    Panel(row, C.surface)
    row.name = Label(row, "", 14, C.cream, 200, "LEFT", true)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -6)
    row.sub = Label(row, "", 10, C.muted, 210, "LEFT", true)
    row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -26)
    row.pips = {}
    for j = 1, PLAN_PIPS do
      local pip = Pip(row, function(b)
        local P = PSS.Planner
        if not row.key then return end
        if b.locked then PSS:Print(string.format(L("planLocked"), b.need or 0)) return end
        local plan = P:Plan()
        local rank = (plan[row.key] == j) and 0 or j
        if not P:Set(row.key, rank) then PSS:Print(L("planSlotsFull")) end
        UI:RefreshPlanner()
      end)
      pip:SetPoint("LEFT", row, "LEFT", 236 + (j - 1) * 20, 0)
      SetTip(pip, function() return row.key and PSS:RankInfoText(row.key, j) or nil end)
      row.pips[j] = pip
    end
    row.plan = Label(row, "", 12, C.gold, 230, "RIGHT", true)
    row.plan:SetPoint("RIGHT", row, "RIGHT", -12, 6)
    row.state = Label(row, "", 10, C.muted, 230, "RIGHT", true)
    row.state:SetPoint("RIGHT", row, "RIGHT", -12, -10)
    f.rows[i] = row
  end
  f.route = MakeButton(f, "", 280, 28, function()
    local n = PSS.Planner:ToRoute()
    PSS:Print(n > 0 and string.format(L("routeFilled"), n) or L("planNothingMissing"))
    UI:RefreshPlanner()
  end, {icon="Ability_Hunter_Pathfinding", iconSize=18, iconLeft=true, size=12})
  f.route.icon:SetTexture("Interface\\Icons\\Ability_Hunter_Pathfinding")
  f.route:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -424)
  f.note = Label(f, "", 10, C.muted, rw - 300, "LEFT")
  f.note:SetPoint("LEFT", f.route, "RIGHT", 14, 0)
  f:Hide()
end

local function PipState(pip, state)
  local ring, core, alpha = C.muted, C.surface, 0.6
  if state == "plan" then ring, core, alpha = C.gold, C.gold, 1
  elseif state == "have" then ring, core, alpha = C.green, C.surface, 1
  elseif state == "locked" then ring, core, alpha = C.muted, C.surface, 0.25 end
  pip.ring:SetVertexColor(ring[1], ring[2], ring[3], alpha)
  pip.core:SetVertexColor(core[1], core[2], core[3], alpha)
end

function UI:RefreshPlanner()
  local f = self.pPlan
  if not f then return end
  local P = PSS.Planner
  local pet = PSS.MyPet
  if not (P and pet and pet.active) then f:Hide() return end
  f:Show()
  local plan, cur = P:Plan(), P:Current()
  local cost, slots, unknown = P:Totals(plan)
  local budget = P:Budget()
  local text
  if budget then
    local left = budget - cost
    text = string.format(L("planTp"), cost, budget, left)
    if left < 0 then text = "|cffff7a5c" .. text .. "|r" end
    f.bar:SetFraction(math.min(1, cost / budget), left < 0 and {1, 0.48, 0.36} or C.gold)
  else
    text = string.format(L("planTpNoBudget"), cost)
    f.bar:SetFraction(0)
  end
  text = text .. "  ·  " .. string.format(L("planSlots"), slots, P.SLOTS)
  if unknown then text = text .. "  ·  " .. L("planUnknownCost") end
  f.tp:SetText(text)
  for _, b in ipairs(f.presets) do b:SetText(L("plan_" .. b.role)) end
  local keys = P:Keys(pet)
  for i, row in ipairs(f.rows) do
    local key = keys[i]
    row.key = key
    if key then
      local maxRank = #PSS.Ranks[key]
      local allowed = P:MaxAllowed(key, pet.level)
      local planned, have = plan[key] or 0, cur[key] or 0
      row.name:SetText(PSS:NameAbility(key))
      local source = SkillSource(key)
      row.sub:SetText(have > 0 and string.format(L("planHave"), have) .. "  ·  " .. source or source)
      for j, pip in ipairs(row.pips) do
        if j <= maxRank then
          local meta = PSS.Ranks[key][j]
          pip.locked = j > allowed
          pip.need = meta and meta.petLevel
          if j <= planned then PipState(pip, "plan")
          elseif pip.locked then PipState(pip, "locked")
          elseif j <= have then PipState(pip, "have")
          else PipState(pip, "none") end
          pip:Show()
        else
          pip:Hide()
        end
      end
      if planned > 0 then
        local c = P:Cost(key, planned)
        row.plan:SetText(string.format(L("planRank"), planned, c))
        local known = PSS.Route and PSS.Route:KnownRank(key) or have
        local learn = PSS.Abilities[key].learn
        if planned > math.max(known, have) then
          row.state:SetText(learn == "beast" and L("planLearnBeast") or L("planLearnTrainer"))
          row.state:SetTextColor(1, 0.71, 0.42)
        elseif planned < have then
          row.state:SetText(L("planLower"))
          row.state:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        else
          row.state:SetText(L("planReady"))
          row.state:SetTextColor(0.49, 0.88, 0.64)
        end
      else
        row.plan:SetText(L("planOff"))
        row.state:SetText(have > 0 and L("planUnlearn") or "")
        row.state:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
      row:SetAlpha(planned > 0 and 1 or 0.75)
      row:Show()
    else
      row:Hide()
    end
  end
  local missing = #P:Missing(plan)
  f.route:SetText(L("planToRoute"))
  f.note:SetText(missing > 0 and string.format(L("planMissing"), missing) or L("planHint"))
end

local function Guard(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    UI.lastError = label .. ": " .. tostring(err)
    if not reportedErrors[label] then
      reportedErrors[label] = true
      PSS:Print("error (" .. label .. "): " .. tostring(err) .. "  - " .. (PSS.version or ""))
    end
  end
  return ok
end
UI.Guard = Guard

-- Pet stat bars. Only stats the client actually reports are shown, in order:
-- happiness, experience, loyalty, training points.
-- Loyalty titles (C_PetInfo.GetPetLoyalty returns only the name on Forever).
local LOYALTY_LEVELS = {
  rebellious=1, unruly=2, submissive=3, dependable=4, faithful=5, ["best friend"]=6,
  ["rebelle"]=1, ["indiscipliné"]=2, ["soumis"]=3, ["dévoué"]=4, ["fidèle"]=5, ["meilleur ami"]=6,
  ["rebellisch"]=1, ["widerspenstig"]=2, ["unterwürfig"]=3, ["zuverlässig"]=4, ["treu"]=5, ["bester freund"]=6,
  ["rebelde"]=1, ["indisciplinado"]=2, ["sumiso"]=3, ["fiable"]=4, ["fiel"]=5, ["mejor amigo"]=6,
  ["ribelle"]=1, ["indisciplinato"]=2, ["sottomesso"]=3, ["affidabile"]=4, ["fedele"]=5, ["migliore amico"]=6,
  ["бунтарский"]=1, ["непослушный"]=2, ["покорный"]=3, ["надежный"]=4, ["преданный"]=5, ["лучший друг"]=6,
}

function UI:RefreshPetStats()
  local card = self.pCard
  if not card or not (PSS.MyPet and PSS.MyPet.active) then return end
  local IsSecret = PSS.IsSecret
  local stats = {}
  -- entry: {label, text, fraction | nil, colour, rawCur, rawMax}
  local function AddRaw(label, cur, max, color)
    if cur == nil or max == nil then return end
    if IsSecret(cur) or IsSecret(max) then
      local ok, text = pcall(string.format, "%s / %s", cur, max)
      table.insert(stats, {label, ok and text or "", nil, color, cur, max})
      return
    end
    cur, max = tonumber(cur), tonumber(max)
    if cur and max and max > 0 then
      table.insert(stats, {label, math.floor(cur) .. " / " .. math.floor(max), cur / max, color})
    end
  end
  local P = C_PetInfo or {}
  -- Happiness
  local h, dmg = SafeCall(P.GetPetHappiness or GetPetHappiness)
  if IsSecret(h) then
    local ok, text = pcall(string.format, "%s%%", dmg)
    table.insert(stats, {L("happiness"), ok and text or "", nil, C.green, h, 3})
  else
    local frac
    if PSS.PetCare then
      local ok, a, _, _, d = pcall(PSS.PetCare.Happiness, PSS.PetCare)
      if ok then h, frac = tonumber(a), tonumber(d) end
    end
    if h and h >= 1 and h <= 3 then
      h = math.floor(h + 0.5)
      local hc = h == 1 and C.red or (h == 2 and {0.94, 0.76, 0.37} or C.green)
      local text = L("happy" .. h)
      dmg = (not IsSecret(dmg)) and tonumber(dmg) or nil
      if dmg then text = text .. "  " .. math.floor(dmg + 0.5) .. "%"
      elseif frac then text = text .. "  " .. math.floor(frac * 100 + 0.5) .. "%" end
      table.insert(stats, {L("happiness"), text, frac or h / 3, hc})
    end
  end
  -- Loyalty
  local loyalty = SafeCall(P.GetPetLoyalty or GetPetLoyalty)
  if IsSecret(loyalty) then
    table.insert(stats, {L("loyalty"), loyalty, 0, {0.50, 0.78, 0.66}})
  elseif type(loyalty) == "string" and loyalty ~= "" then
    local level = tonumber(loyalty:match("(%d+)")) or LOYALTY_LEVELS[string.lower(loyalty)]
    local text = level and (loyalty .. "  " .. level .. "/6") or loyalty
    table.insert(stats, {L("loyalty"), text, level and level / 6 or 0, {0.50, 0.78, 0.66}})
  end
  -- Training points: shown as free of total
  local tp, used = SafeCall(P.GetPetTrainingPoints or GetPetTrainingPoints)
  if IsSecret(tp) or IsSecret(used) then
    AddRaw(L("trainingPoints"), used, tp, C.gold)
  else
    tp, used = tonumber(tp), tonumber(used) or 0
    if tp and tp > 0 then
      local free = math.floor(tp - used)
      table.insert(stats, {L("trainingPoints"), string.format(L("tpFree"), free, math.floor(tp)), free / tp, C.gold})
    end
  end
  AddRaw(L("petXP"), SafeCall(GetPetExperience))
  if #stats < 5 then
    local hp, hpMax = SafeCall(UnitHealth, "pet"), SafeCall(UnitHealthMax, "pet")
    AddRaw(L("petHealth"), hp, hpMax, {0.40, 0.80, 0.42})
  end
  if #stats < 5 then
    local ptype, ptoken = SafeCall(UnitPowerType, "pet")
    if not IsSecret(ptype) and tonumber(ptype) and tonumber(ptype) ~= 4 then
      local name = (not IsSecret(ptoken) and type(ptoken) == "string" and _G[ptoken]) or L("petPower")
      AddRaw(name, SafeCall(UnitPower, "pet", ptype), SafeCall(UnitPowerMax, "pet", ptype), {0.95, 0.80, 0.35})
    end
  end
  -- The XP colour (AddRaw default) fills in when no colour was given.
  for i, m in ipairs(card.meters) do
    local st = stats[i]
    Show(m.key, st ~= nil); Show(m.value, st ~= nil); Show(m.bar, st ~= nil)
    if st then
      local color = st[4] or {0.56, 0.66, 0.96}
      m.key:SetText(st[1])
      if not pcall(m.value.SetText, m.value, st[2]) then m.value:SetText("") end
      m.value:SetTextColor(color[1], color[2], color[3])
      if st[3] then m.bar:SetFraction(st[3], color) else m.bar:SetRaw(st[5], st[6], color) end
    end
  end
  if #stats == 0 then
    card.none:SetText(L("petStatsNone"))
    card.none:Show()
  end
end

function UI:RefreshAmmo()
  local ammo = self.pCard and self.pCard.ammo
  if not ammo then return end
  local A = PSS.Ammo
  local text, count, kind = nil, nil, nil
  if A then text, count, kind = A:StatusText() end
  if not text then ammo:Hide() return end
  ammo:Show()
  local _, _, equipped = A:Count()
  local icon = equipped and ((C_Item and SafeCall(C_Item.GetItemIconByID, equipped)) or SafeCall(GetItemIcon, equipped))
  ammo.icon:SetTexture(icon or (kind == "bullet" and "Interface\\Icons\\INV_Ammo_Bullet_01" or "Interface\\Icons\\INV_Ammo_Arrow_01"))
  ammo.count:SetText(text)
  local spot = A:Nearest(kind)
  ammo.place:SetText(spot and string.format(L("ammoNearest"), A:PlaceText(spot)) or "")
  Show(ammo.go, spot ~= nil)
end

function UI:RefreshPet(alreadyScanned)
  if not self.pCard or self.view ~= "pet" then return end
  local pet = PSS.MyPet
  if not pet then return end
  if not alreadyScanned then
    pet:Scan()
    if PSS.Stable and PSS.Stable.SnapshotActive then PSS.Stable:SnapshotActive() end
  end
  local card = self.pCard
  local active = pet.active
  for _, w in ipairs({card.sub, card.food}) do Show(w, active) end
  if not active then
    for _, m in ipairs(card.meters) do Show(m.key, false); Show(m.value, false); Show(m.bar, false) end
  end
  Show(card.none, not active)
  Show(card.passport, active)
  Show(card.share, active)
  self.feedFood = nil
  if not active then
    card.view:SetSubject({}, FamilyIcon(nil))
    card.name:SetText(L("petNone"))
    card.none:SetText(L("petSummon"))
  else
    card.view:SetSubject({unit="pet"}, FamilyIcon(pet.family))
    card.name:SetText(pet.name or "?")
    local speed = SafeCall(UnitAttackSpeed, "pet")
    local sub = (pet.family and PSS:NameFamily(pet.family) or "?") .. "  ·  " .. L("level") .. " " .. tostring(pet.level or "?")
    if speed then sub = sub .. "  ·  " .. string.format(L("atlasSpeed"), speed) end
    card.sub:SetText(sub)
    Guard("pet stats", self.RefreshPetStats, self)
    Guard("pet food", self.RefreshPetFood, self)
  end
  Guard("pet skills", self.RefreshPetSkills, self, pet, active)
  Guard("stable", self.RefreshPetStable, self)
  Guard("ammo", self.RefreshAmmo, self)
  self:PlaceFeedOverlay()
end

function UI:RefreshPetFood()
  local card = self.pCard
  do
    local f = card.food
    local best = PSS.PetCare and PSS.PetCare:BestFood()
    local diet = PSS.PetCare and PSS.PetCare:DietText()
    f.diet:SetText(diet and string.format(L("petDiet"), diet) or "")
    if best then
      f.icon:SetTexture(best.icon or "Interface\\Icons\\INV_Misc_Food_14")
      if f.icon.SetDesaturated then f.icon:SetDesaturated(false) end
      f.name:SetText(best.name)
      f.count:SetText((best.count or 1) > 1 and ("x" .. best.count) or "")
      f.slotText:SetText("")
      self.feedFood = best
    else
      f.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
      if f.icon.SetDesaturated then f.icon:SetDesaturated(true) end
      f.name:SetText(L("petNoFood"))
      f.count:SetText("")
      f.slotText:SetText("")
    end
  end
end

function UI:RefreshPetSkills(pet, active)
  for _, row in ipairs(self.pSkillRows) do row:Hide() end
  if self.pPlanBtn then
    self.pPlanBtn:SetText(L(self.petPlanner and "planBack" or "planOpen"))
    SetActive(self.pPlanBtn, self.petPlanner)
    Show(self.pPlanBtn, active)
  end
  if self.petPlanner and active then
    self.pSkillNote:Hide()
    self.pSkillsTitle:SetText(L("planTitle"))
    self.pLegend:SetText(L("planLegend"))
    self:RefreshPlanner()
    return
  end
  if self.pPlan then self.pPlan:Hide() end
  local used = 0
  if active then
    local learned = 0
    for _, s in ipairs(pet.spells or {}) do if s.key and PSS.Abilities[s.key] then learned = learned + 1 end end
    self.pSkillsTitle:SetText(string.format(L("skillsHeader"), learned))
    for _, s in ipairs(pet.spells or {}) do
      if used >= SKILL_ROWS then break end
      if s.key and PSS.Abilities[s.key] then
        used = used + 1
        self:FillSkillRow(self.pSkillRows[used], s.key, s.rank, pet.level, false)
      end
    end
    local available = pet:AvailableSkills()
    for _, key in ipairs(available) do
      if used >= SKILL_ROWS then break end
      used = used + 1
      self:FillSkillRow(self.pSkillRows[used], key, 0, pet.level, true)
    end
    if used == 0 then self.pSkillNote:SetText(L("petUnavailable")) end
    Show(self.pSkillNote, used == 0)
  else
    self.pSkillsTitle:SetText(string.format(L("skillsHeader"), 0))
    self.pSkillNote:SetText(L("petSummon"))
    self.pSkillNote:Show()
  end
  self.pLegend:SetText(L("pipsLegend"))
end

function UI:RefreshPetStable()
  local stable = PSS.Stable
  if stable and stable.Scan and _G.PetStableFrame and _G.PetStableFrame:IsShown() then stable:Scan() end
  local records = stable and stable:Records() or {}
  self.pStableTitle:SetText(L("stableTitle"))
  self.pStableInfo:SetText(#records > 0 and string.format(L("stableSaved"), #records) or L("stableOpen"))
  self.pStableScan:SetText(L("stableScan"))
  for i, c in ipairs(self.pStable) do
    local e = records[i]
    c.entry, c.index = e, i
    Show(c.icon, e ~= nil); Show(c.name, e ~= nil); Show(c.sub, e ~= nil); Show(c.skills, e ~= nil)
    Show(c.empty, e == nil)
    if e then
      c.icon:SetTexture(FamilyIcon(e.family))
      c.name:SetText(e.name or string.format(L("stableSlot"), tonumber(e.slot) or i))
      c.sub:SetText((e.family and PSS:NameFamily(e.family) or "?") .. "  ·  " .. string.format(L("stableLevel"), tostring(e.level or "?")))
      local names = {}
      for _, s in ipairs(e.spells or {}) do
        local n = s.key and PSS:NameAbility(s.key) or s.name
        if n then table.insert(names, n .. (s.rank and (" " .. s.rank) or "")) end
      end
      c.skills:SetText(#names > 0 and table.concat(names, ", ") or L("stableSkillsMissing"))
      SetEdgeColor(c.pssEdges, (stable and stable.selected == i) and C.gold or C.border)
    else
      c.empty:SetText(L("stableFree"))
      SetEdgeColor(c.pssEdges, C.border)
    end
  end
end

-- Feed button overlay -------------------------------------------------------
-- Casting needs a secure button. It is parented to UIParent (not to this
-- window) and only positioned over the card out of combat, so the window itself
-- never becomes protected and can always be moved or closed.
local function FeedSpellName()
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(6991)
    if info and info.name then return info.name end
  end
  return (GetSpellInfo and GetSpellInfo(6991)) or "Feed Pet"
end

function UI:StyleFeedOverlay()
  local b = self.feedButton
  if not b then return end
  if Textured() then
    b.bg:SetTexture(TEX .. "ClassicButton")
    b.bg:SetVertexColor(1, 1, 1, 1)
    b.text:SetTextColor(1, 0.82, 0.15)
  else
    b.bg:SetTexture(WHITE)
    b.bg:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    b.text:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
  end
end

function UI:PlaceFeedOverlay()
  if InCombat() then self.feedPending = true return end
  self.feedPending = false
  local slot = self.feedSlot
  local food = self.feedFood
  local want = frame and frame:IsShown() and self.view == "pet" and food and slot and slot:IsVisible()
  if not want then
    if self.feedButton then self.feedButton:Hide() end
    return
  end
  local b = self.feedButton
  if not b then
    b = CreateFrame("Button", "PetSkillScoutCardFeedButton", UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata("DIALOG")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetVertexColor(1, 1, 1, 0.15)
    hl:SetAllPoints(b)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
      if not (GameTooltip and UI.feedFood) then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(PSS:Safe(string.format(L("feedButtonTip"), PSS.Plain(UnitName("pet")) or "?", UI.feedFood.name)), 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.feedButton = b
  end
  local left, bottom = slot:GetLeft(), slot:GetBottom()
  if not (left and bottom) then b:Hide() return end
  local ratio = slot:GetEffectiveScale() / UIParent:GetEffectiveScale()
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
  b:SetSize(slot:GetWidth() * ratio, slot:GetHeight() * ratio)
  b:SetFrameLevel(frame:GetFrameLevel() + 60)
  b.text:SetFont(FONT, math.max(9, math.floor(13 * ratio + 0.5)), "")
  b.text:SetText(L("feedNow"))
  PSS.SetFeedAttributes(b, food)
  self:StyleFeedOverlay()
  b:Show()
end

local combatWatch = CreateFrame("Frame")
pcall(combatWatch.RegisterEvent, combatWatch, "PLAYER_REGEN_ENABLED")
pcall(combatWatch.RegisterEvent, combatWatch, "BAG_UPDATE_DELAYED")
combatWatch:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" then
    if UI.view == "pet" and frame and frame:IsShown() then UI:RefreshPet(true) end
  elseif UI.feedPending then
    UI:PlaceFeedOverlay()
  end
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function RefreshRareMap() if PSS.RareMap then PSS.RareMap:Refresh() end end
local function SkinApply()
  if PSS.Skin then PSS.Skin:Refresh() end
  if PSS.Layout then PSS.Layout:Apply() end
end
local SETTINGS = {
  {id="general", title="setGeneral", sub="setGeneralSub", rows={
    {key="language", label="optLanguage", hint="optLanguageHint", kind="language"},
    {key="theme", label="optTheme", hint="optThemeHint", kind="choice", default="journal",
      options={{"journal","themeJournal"},{"classic","themeWoW"},{"blizzard","themeClassic"},{"moonglade","themeMoon"}},
      apply=function() UI:ApplyTheme(); UI:RefreshView() end},
    {key="uiScale", label="optScale", hint="optScaleHint", kind="choice", default=1,
      options={{0.85,"sizeS"},{1,"sizeM"},{1.15,"sizeL"}}, apply=function() UI:ApplyScale() end},
    {key="rememberPos", label="optRemember", hint="optRememberHint", kind="toggle", default=true,
      apply=function() SavePosition() end},
    {key="minimapButton", label="optMinimapBtn", hint="optMinimapBtnHint", kind="toggle", default=true,
      apply=function() if PSS.UpdateLaunchers then PSS:UpdateLaunchers() end end},
    {key="floatingLauncher", label="optLauncher", hint="optLauncherHint", kind="toggle", default=false,
      apply=function() if PSS.UpdateLaunchers then PSS:UpdateLaunchers() end end},
  }},
  {id="interface", title="setInterface", sub="setInterfaceSub", rows={
    {key="skinGame", label="optSkinGame", hint="optSkinGameHint", kind="toggle", default=false, apply=SkinApply},
    {key="skinUnits", label="optSkinUnits", hint="optSkinUnitsHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinBars", label="optSkinBars", hint="optSkinBarsHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinChat", label="optSkinChat", hint="optSkinChatHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinChatSize", label="optChatSize", hint="optChatSizeHint", kind="choice", default="m",
      options={{"s","sizeS"},{"m","sizeM"},{"l","sizeL"},{"xl","sizeXL"}},
      apply=function() if PSS.Layout and PSS.Layout.applied.chat then PSS.Layout:PlaceChat() end end},
    {key="skinMinimap", label="optSkinMinimap", hint="optSkinMinimapHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinMinimapBar", label="optMinimapBar", hint="optMinimapBarHint", kind="toggle", default=true,
      apply=function() if PSS.Layout and PSS.Layout.applied.minimap then PSS.Layout:SquareMinimapButtons() end end},
    {key="skinMinimapSize", label="optMinimapSize", hint="optMinimapSizeHint", kind="choice", default=176,
      options={{150,"sizeS"},{176,"sizeM"},{210,"sizeL"},{250,"sizeXL"}},
      apply=function()
        local LY = PSS.Layout
        if LY and LY.applied.minimap then
          LY:PlaceMinimap(); LY:RefreshMinimapButtons(); LY:SquareMinimapButtons()
        end
      end},
    {key="skinPlates", label="optSkinPlates", hint="optSkinPlatesHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinParty", label="optSkinParty", hint="optSkinPartyHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinBags", label="optSkinBags", hint="optSkinBagsHint", kind="toggle", default=true, apply=SkinApply},
    {key="skinFonts", label="optSkinFonts", hint="optSkinFontsHint", kind="toggle", default=true, apply=SkinApply},
    {key="layoutMove", label="optMove", hint="optMoveHint", kind="action", button="moveBtn",
      run=function() if PSS.Layout then PSS.Layout:Unlock(true) end end},
    {key="skinReload", label="optSkinReload", hint="optSkinReloadHint", kind="action", button="skinReloadNow",
      run=function() if ReloadUI then ReloadUI() end end},
  }},
  {id="hunter", title="setHunter", sub="setHunterSub", rows={
    {key="shotTimer", label="optShotTimer", hint="optShotTimerHint", kind="toggle", default=true},
    {key="fastLoot", label="optFastLoot", hint="optFastLootHint", kind="toggle", default=false,
      text=function() local o = PSS.FastLoot and PSS.FastLoot:Other(); if o then return string.format(PSS:L("optFastLootOther"), o) end end},
    {key="spellBarAuto", label="optSpellBar", hint="optSpellBarHint", kind="toggle", default=true},
    {key="petBarAuto", label="optPetBar", hint="optPetBarHint", kind="toggle", default=true},
    {key="gearTooltip", label="optGearTooltip", hint="optGearTooltipHint", kind="toggle", default=true},
    {key="gearQuest", label="optGearQuest", hint="optGearQuestHint", kind="toggle", default=true},
    {key="gearRolls", label="optGearRolls", hint="optGearRollsHint", kind="toggle", default=true},
    {key="gearBagArrows", label="optGearBagArrows", hint="optGearBagArrowsHint", kind="toggle", default=true,
      apply=function() if PSS.GearCompare then PSS.GearCompare:MarkAllBags() end end},
  }},
  {id="quests", title="setQuests", sub="setQuestsSub", rows={
    {key="questAlert", label="optQuestAlert", hint="optQuestAlertHint", kind="toggle", default=true},
    {key="questWorth", label="optQuestWorth", hint="optQuestWorthHint", kind="toggle", default=true},
    {key="questPins", label="optQuestPins", hint="optQuestPinsHint", kind="toggle", default=false,
      apply=function() if PSS.QuestPins then PSS.QuestPins:Refresh() end end},
    {key="questPinsSkip", label="optQuestPinsSkip", hint="optQuestPinsSkipHint", kind="toggle", default=false,
      apply=function() if PSS.QuestPins then PSS.QuestPins:Refresh() end end},
    {key="questLearn", label="optQuestLearn", hint="optQuestLearnHint", kind="toggle", default=true},
    {key="questMinimap", label="optQuestMinimap", hint="optQuestMinimapHint", kind="toggle", default=true,
      apply=function() if PSS.QuestPins then PSS.QuestPins:Refresh() end end},
    {key="questObjPins", label="optQuestObj", hint="optQuestObjHint", kind="toggle", default=true,
      apply=function() if PSS.QuestPins then PSS.QuestPins:Refresh() end end},
    {key="questAuto", label="optQuestAuto", hint="optQuestAutoHint", kind="choice", default="off",
      options={{"off","qAutoOff"},{"worth","qAutoWorth"},{"all","qAutoAll"}}},
    {key="questTurnIn", label="optQuestTurnIn", hint="optQuestTurnInHint", kind="toggle", default=false},
    {key="questDropGrey", label="optQuestDrop", hint="optQuestDropHint", kind="toggle", default=false},
  }},
  {id="map", title="setMap", sub="setMapSub", rows={
    {key="rareMapPins", label="rareMapPins", hint="optMapPinsHint", kind="toggle", default=true, apply=RefreshRareMap},
    {key="minimapPins", label="atlasMinimapOpt", hint="optMinimapHint", kind="toggle", default=true,
      apply=function() if PSS.Minimap then PSS.Minimap:Refresh() end end},
    {key="rareIconSize", label="optIconSize", hint="optIconSizeHint", kind="choice", default="s",
      options={{"s","sizeS"},{"m","sizeM"},{"l","sizeL"}}, apply=RefreshRareMap},
  }},
  {id="alerts", title="setAlerts", sub="setAlertsSub", rows={
    {key="rareRadarEnabled", label="optRadar", hint="optRadarHint", kind="toggle", default=true},
    {key="rareAlertPopup", label="rareAlertPopup", hint="optPopupHint", kind="toggle", default=true},
    {key="rareSound", label="optSound", hint="optSoundHint", kind="toggle", default=true},
    {key="rareChat", label="optChat", hint="optChatHint", kind="toggle", default=true},
    {key="syncEnabled", label="optSync", hint="optSyncHint", kind="toggle", default=true},
    {key="syncNotify", label="optSyncNotify", hint="optSyncNotifyHint", kind="choice", default="off",
      options={{"wanted","syncWanted"},{"all","syncAll"},{"off","syncOff"}}},
    {key="rareTimerAlert", label="optTimerAlert", hint="optTimerAlertHint", kind="toggle", default=true},
  }},
  {id="network", title="setNet", sub="setNetSub", rows={
    {key="netEnabled", label="optNet", hint="optNetHint", kind="toggle", default=true,
      apply=function()
        if not PSS.Net then return end
        if PetSkillScoutDB.netEnabled == false then PSS.Net:Leave() else PSS.Net:ShowConnect(true); PSS.Net:Hello(true) end; PSS.Net:UpdateJoinButtons()
      end},
    {key="netChatTab", label="optNetChat", hint="optNetChatHint", kind="toggle", default=false,
      apply=function() PetSkillScoutDB.netChatMade = nil; if PSS.NetChat then PSS.NetChat.tried = nil; PSS.NetChat:Sync() end end},
    {key="netConnect", label="optNetConnect", hint="optNetConnectHint", kind="action", button="netConnectBtn",
      run=function() if PSS.Net and not PSS.Net:ShowConnect(true) then PSS:Print(PSS:L(PSS.Net:ChannelID() and "netJoined" or "netNoConnect")) end end},
    {key="netInfo", label="optNetInfo", hint="", kind="info",
      text=function()
        local N = PSS.Net
        if not N then return "" end
        return PSS:Safe(string.format(L("netInfo"), N:OnlineCount(), N:ChannelID() and L("netConnected") or L("netOffline")))
      end},
    {key="announceOn", label="optAnn", hint="optAnnHint", kind="toggle", default=true},
    {key="announceRare", label="optAnnRare", hint="", kind="toggle", default=true},
    {key="announceRank", label="optAnnRank", hint="", kind="toggle", default=true},
    {key="announceMilestone", label="optAnnMile", hint="", kind="toggle", default=true},
    {key="showcaseShare", label="optShowcase", hint="optShowcaseHint", kind="toggle", default=true,
      apply=function() if PSS.Showcase and PetSkillScoutDB.showcaseShare ~= false then PSS.Showcase:Send() end end},
    {key="queueEnabled", label="optQueue", hint="optQueueHint", kind="toggle", default=true,
      apply=function() if PSS.Queue then PSS.Queue:Tick() end end},
    {key="queueAuto", label="optQueueAuto", hint="optQueueAutoHint", kind="toggle", default=true},
  }},
  {id="ammo", title="setAmmo", sub="setAmmoSub", rows={
    {key="ammoWarn", label="optAmmoWarn", hint="optAmmoWarnHint", kind="choice", default=200,
      options={{100,"ammo100"},{200,"ammo200"},{500,"ammo500"},{false,"ammoOff"}},
      apply=function() if PSS.Ammo then PSS.Ammo:Check() end end},
    {key="ammoDungeon", label="optAmmoDungeon", hint="optAmmoDungeonHint", kind="choice", default=1000,
      options={{500,"ammo500"},{1000,"ammo1000"},{2000,"ammo2000"},{false,"ammoOff"}}},
    {key="ammoVendors", label="optAmmoVendors", hint="optAmmoVendorsHint", kind="info",
      text=function()
        local A = PSS.Ammo
        if not A then return "" end
        local text, _, kind = A:StatusText()
        local parts = {string.format(L("ammoVendorsKnown"), A:VendorCount())}
        if text then
          table.insert(parts, 1, text)
          local spot = A:Nearest(kind)
          if spot then table.insert(parts, string.format(L("ammoNearest"), A:PlaceText(spot))) end
        end
        return PSS:Safe(table.concat(parts, "  ·  "))
      end},
    {key="ammoGo", label="optAmmoGo", hint="optAmmoGoHint", kind="action", button="ammoGoBtn",
      run=function() if PSS.Ammo then PSS.Ammo:Go() end end},
  }},
  {id="tips", title="setTips", sub="setTipsSub", rows={
    {key="tooltip", label="atlasTooltipOpt", hint="optTipHint", kind="toggle", default=true},
    {key="tooltipSkills", label="optTipSkills", hint="optTipSkillsHint", kind="toggle", default=true},
    {key="tooltipSeen", label="optTipSeen", hint="optTipSeenHint", kind="toggle", default=true},
  }},
  {id="dungeon", title="setDungeon", sub="setDungeonSub", rows={
    {key="guardFall", label="optGuardFall", hint="optGuardFallHint", kind="toggle", default=true},
    {key="guardAggro", label="optGuardAggro", hint="optGuardAggroHint", kind="toggle", default=true},
    {key="guardAggressive", label="optGuardAggressive", hint="optGuardAggressiveHint", kind="toggle", default=true,
      apply=function() if PSS.PetGuard then PSS.PetGuard.CheckStance() end end},
    {key="guardQuiet", label="optGuardQuiet", hint="optGuardQuietHint", kind="toggle", default=false},
    {key="guardSound", label="optGuardSound", hint="optGuardSoundHint", kind="toggle", default=true},
    {key="guardKeys", label="optGuardKeys", hint="optGuardKeysHint", kind="info",
      text=function() return PSS.PetGuard and PSS.PetGuard:KeysText() or "" end},
    {key="guardTest", label="optGuardTest", hint="optGuardTestHint", kind="action", button="guardTestBtn",
      run=function() if PSS.PetGuard then PSS.PetGuard:Test("fall") end end},
  }},
  {id="care", title="setCare", sub="setCareSub", rows={
    {key="petCareReminder", label="careReminderOpt", hint="optRemindHint", kind="toggle", default=true},
    {key="feedButton", label="optFeed", hint="optFeedHint", kind="choice", default="unhappy",
      options={{"unhappy","feedUnhappy"},{"always","feedAlways"},{"off","feedOff"}},
      get=function()
        local v = PetSkillScoutDB and PetSkillScoutDB.feedButton
        if v == false then return "off" elseif v == "always" then return "always" end
        return "unhappy"
      end,
      set=function(v)
        if v == "off" then PetSkillScoutDB.feedButton = false
        elseif v == "always" then PetSkillScoutDB.feedButton = "always"
        else PetSkillScoutDB.feedButton = nil end
      end,
      apply=function() if PSS.PetCare then PSS.PetCare:UpdateButton() end end},
  }},
}

local function OptionValue(def)
  if def.get then return def.get() end
  local v = PetSkillScoutDB and PetSkillScoutDB[def.key]
  if v == nil then return def.default end
  return v
end
local function SetOption(def, value)
  if not PetSkillScoutDB then return end
  if def.set then def.set(value) else PetSkillScoutDB[def.key] = value end
  if def.apply then def.apply() end
  UI:RefreshSettings()
end

local function Switch(parent, onClick)
  local s = CreateFrame("Button", nil, parent)
  s:SetSize(44, 22)
  s.track = s:CreateTexture(nil, "BACKGROUND")
  s.track:SetTexture(WHITE)
  s.track:SetAllPoints(s)
  s.knob = s:CreateTexture(nil, "ARTWORK")
  s.knob:SetTexture(CIRCLE)
  s.knob:SetSize(16, 16)
  s:SetScript("OnClick", onClick)
  function s:Set(on)
    local t = on and C.gold or C.border
    self.track:SetVertexColor(t[1], t[2], t[3], 1)
    local k = on and C.ink or C.muted
    self.knob:SetVertexColor(k[1], k[2], k[3], 1)
    self.knob:ClearAllPoints()
    self.knob:SetPoint("LEFT", self, "LEFT", on and 25 or 3, 0)
  end
  return s
end

function UI:BuildSettings()
  local p = CreateFrame("Frame", nil, self.body)
  p:SetAllPoints(self.body)
  self.views.settings = p
  -- Section navigation
  local nav = CreateFrame("Frame", nil, p)
  nav:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  nav:SetSize(210, BODY_H)
  Panel(nav, C.surface)
  self.sTitle = Label(nav, "", 18, C.cream, 190, "LEFT", true)
  self.sTitle:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -14)
  self.sNav = {}
  for i, sec in ipairs(SETTINGS) do
    local b = MakeButton(nav, "", 186, 34, function() UI.settingsSection = sec.id; UI:RefreshSettings() end)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 12, -50 - (i - 1) * 40)
    b.section = sec
    local fs = b:GetFontString()
    if fs then fs:ClearAllPoints(); fs:SetPoint("LEFT", b, "LEFT", 12, 0); fs:SetJustifyH("LEFT") end
    self.sNav[i] = b
  end
  self.sVersion = Label(nav, "", 10, C.muted, 190, "LEFT", true)
  self.sVersion:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 14, 12)

  -- Rows (one container per section)
  local cw = BODY_W - 210 - 16 - 296
  self.sHeading = Label(p, "", 18, C.cream, cw, "LEFT", true)
  self.sHeading:SetPoint("TOPLEFT", p, "TOPLEFT", 226, -6)
  self.sSub = Label(p, "", 12, C.muted, cw, "LEFT", true)
  self.sSub:SetPoint("TOPLEFT", p, "TOPLEFT", 226, -32)
  self.sSections = {}
  local viewH = BODY_H - 60
  for _, sec in ipairs(SETTINGS) do
    -- Rows scroll inside the window (mouse wheel + slim bar in the gap before the preview).
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", 226, -60)
    sf:SetSize(cw, viewH)
    local box = CreateFrame("Frame", nil, sf)
    box:SetSize(cw, viewH)
    sf:SetScrollChild(box)
    box.sf = sf
    box.rows = {}
    local y = 0
    for i, def in ipairs(sec.rows) do
      local row = CreateFrame("Frame", nil, box)
      local toggle = def.kind == "toggle" or def.kind == "action"
      row:SetSize(cw, toggle and 58 or 66)
      row:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
      y = y + (toggle and 58 or 66) + 8
      Panel(row, C.surface)
      row.def = def
      local narrow = def.kind == "action" and cw - 190 or cw - 90
      row.label = Label(row, "", 14, C.cream, toggle and narrow or cw - 340, "LEFT", true)
      row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -12)
      -- Choice rows: controls top right, the hint gets the full width below.
      row.hint = Label(row, "", 11, C.muted, toggle and narrow or cw - 28, "LEFT", true)
      row.hint:SetPoint("TOPLEFT", row, "TOPLEFT", 14, toggle and -34 or -44)
      if def.kind == "toggle" then
        row.switch = Switch(row, function() SetOption(def, not OptionValue(def)) end)
        row.switch:SetPoint("RIGHT", row, "RIGHT", -14, 0)
      elseif def.kind == "choice" then
        row.options = {}
        local n = #def.options
        local bw = n >= 4 and 74 or 96
        for j, opt in ipairs(def.options) do
          local b = MakeButton(row, "", bw, 28, function() SetOption(def, opt[1]) end, {size=12})
          b:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14 - (n - j) * (bw + 4), -8)
          b.value, b.key, b.minW = opt[1], opt[2], bw
          row.options[j] = b
        end
      elseif def.kind == "action" then
        row.action = MakeButton(row, "", 150, 30, function() def.run() end, {size=12})
        row.action:SetPoint("RIGHT", row, "RIGHT", -14, 0)
      elseif def.kind == "language" then
        local codes = {}
        for _, item in ipairs(PSS.languageOptions) do table.insert(codes, item.code) end
        row.dd = MakeDropdown(row, codes, function() return (PetSkillScoutDB and PetSkillScoutDB.language) or "en" end, 180,
          function(v) PetSkillScoutDB.language = v; UI:Rebuild() end, function(v) return PSS:LanguageName(v) end)
        -- The visible field starts 16 px into the dropdown frame.
        row.dd:SetPoint("TOPLEFT", row, "TOPRIGHT", -(180 + 14 + 16), -6)
        self.dropdowns = self.dropdowns or {}
        table.insert(self.dropdowns, row.dd)
      end
      box.rows[i] = row
    end
    box:SetHeight(math.max(viewH, y - 8))
    local bar = Solid(p, "OVERLAY", C.gold, 0.55)
    bar:SetWidth(4)
    sf.bar = bar
    function sf:Range() return math.max(0, (box:GetHeight() or 0) - viewH) end
    function sf:ScrollTo(v)
      local range = self:Range()
      v = math.max(0, math.min(range, v or 0))
      self:SetVerticalScroll(v)
      if range <= 0 then bar:Hide(); return end
      local h = math.max(24, viewH * viewH / (viewH + range))
      bar:SetHeight(h)
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, -(viewH - h) * v / range)
      bar:Show()
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(f, delta) f:ScrollTo((f:GetVerticalScroll() or 0) - delta * 66) end)
    sf:ScrollTo(0)
    self.sSections[sec.id] = box
  end

  -- Preview
  local pv = CreateFrame("Frame", nil, p)
  pv:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  pv:SetSize(280, BODY_H)
  Panel(pv, C.surface)
  self.sPreviewTitle = Label(pv, "", 11, C.muted, 250, "LEFT", true)
  self.sPreviewTitle:SetPoint("TOPLEFT", pv, "TOPLEFT", 14, -14)
  local tip = CreateFrame("Frame", nil, pv)
  tip:SetPoint("TOPLEFT", pv, "TOPLEFT", 14, -36)
  tip:SetSize(252, 190)
  local tbg = tip:CreateTexture(nil, "BACKGROUND")
  tbg:SetTexture(WHITE)
  tbg:SetVertexColor(0.04, 0.06, 0.10, 0.96)
  tbg:SetAllPoints(tip)
  local edges = {}
  for _, def in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
    local t = tip:CreateTexture(nil, "BORDER")
    t:SetTexture(WHITE)
    t:SetVertexColor(0.23, 0.29, 0.42, 1)
    t:SetPoint(def[1], tip, def[1], 0, 0)
    t:SetPoint(def[2], tip, def[2], 0, 0)
    if def[3] then t:SetHeight(1) else t:SetWidth(1) end
    table.insert(edges, t)
  end
  tip.lines = {}
  for i = 1, 10 do
    local fs = tip:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, i == 1 and 13 or 11, "")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(232)
    if i == 1 then fs:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -9)
    else fs:SetPoint("TOPLEFT", tip.lines[i - 1], "BOTTOMLEFT", 0, -3) end
    tip.lines[i] = fs
  end
  self.sTip = tip
  -- Alert preview
  local alert = CreateFrame("Frame", nil, pv)
  alert:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -14)
  alert:SetSize(252, 64)
  Panel(alert, C.deep)
  SetEdgeColor(alert.pssEdges, STATUS.want.edge)
  alert.portrait = alert:CreateTexture(nil, "ARTWORK")
  alert.portrait:SetSize(44, 44)
  alert.portrait:SetPoint("LEFT", alert, "LEFT", 10, 0)
  alert.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  alert.head = Label(alert, "", 11, C.gold, 180, "LEFT", true)
  alert.head:SetPoint("TOPLEFT", alert, "TOPLEFT", 64, -14)
  alert.body = Label(alert, "", 11, C.muted, 180, "LEFT", true)
  alert.body:SetPoint("TOPLEFT", alert, "TOPLEFT", 64, -34)
  self.sAlert = alert
  self.sPreviewNote = Label(pv, "", 10, C.muted, 252, "LEFT")
  self.sPreviewNote:SetPoint("TOPLEFT", alert, "BOTTOMLEFT", 0, -12)
end

local PREVIEW_NPC = 1132 -- Timber (Dun Morogh): a rare wolf
function UI:RefreshSettings()
  if not self.sNav then return end
  self.sTitle:SetText(L("settings"))
  self.sVersion:SetText("PetSkillScout " .. tostring(PSS.version) .. "  ·  " .. PSS:Credit(true) .. "  ·  /pss")
  local current
  for _, b in ipairs(self.sNav) do
    b:SetText(L(b.section.title))
    SetActive(b, b.section.id == self.settingsSection)
    if b.section.id == self.settingsSection then current = b.section end
  end
  current = current or SETTINGS[1]
  self.sHeading:SetText(L(current.title))
  self.sSub:SetText(L(current.sub))
  for id, box in pairs(self.sSections) do Show(box.sf, id == current.id) end
  local box = self.sSections[current.id]
  if self.sShownSection ~= current.id then
    self.sShownSection = current.id
    box.sf:ScrollTo(0)
  end
  for _, row in ipairs(box.rows) do
    local def = row.def
    row.label:SetText(L(def.label))
    row.hint:SetText(def.text and def.text() or L(def.hint))
    if row.action then row.action:SetText(L(def.button)) end
    local value = OptionValue(def)
    if row.switch then row.switch:Set(value and true or false) end
    local x = -14
    for j = #(row.options or {}), 1, -1 do
      local b = row.options[j]
      b:SetText(L(b.key))
      SetActive(b, b.value == value)
      local fs = b:GetFontString()
      local w = math.max(b.minW or 74, math.ceil((fs and fs:GetStringWidth() or 0) + 18))
      b:SetWidth(w)
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", row, "TOPRIGHT", x, -8)
      x = x - w - 4
    end
    if row.dd then row.dd:Sync() end
  end
  -- Tooltip preview (real lines for a sample beast with the current options)
  self.sPreviewTitle:SetText(L("preview"))
  local tip = self.sTip
  local rec = PSS.Atlas and PSS.Atlas:Get(PREVIEW_NPC)
  local lines = {}
  table.insert(lines, {(rec and rec.name or "Timber"), 1, 1, 1})
  table.insert(lines, {L("level") .. " " .. (rec and LevelText(rec) or "10"), 0.78, 0.78, 0.78})
  local tooltipOn = not PetSkillScoutDB or PetSkillScoutDB.tooltip ~= false
  if tooltipOn and PSS.Tooltip and PSS.Tooltip.Lines then
    table.insert(lines, {"PetSkillScout", 0.44, 0.84, 1})
    for _, l in ipairs(PSS.Tooltip:Lines(PREVIEW_NPC, true)) do table.insert(lines, l) end
  elseif not tooltipOn then
    table.insert(lines, {L("previewOff"), 0.5, 0.5, 0.5})
  end
  for i, fs in ipairs(tip.lines) do
    local l = lines[i]
    if l then
      fs:SetText(PSS:Safe(l[1]))
      fs:SetTextColor(l[2] or 1, l[3] or 1, l[4] or 1)
      fs:Show()
    else
      fs:Hide()
    end
  end
  local height = 18
  for i, fs in ipairs(tip.lines) do if lines[i] then height = height + (fs:GetStringHeight() or 14) + 3 end end
  tip:SetHeight(math.max(60, height))
  local alert = self.sAlert
  alert.portrait:SetTexture(FamilyIcon(rec and rec.family or "Wolf"))
  alert.head:SetText(L("rareAlertHeader"))
  alert.body:SetText((rec and rec.name or "Timber") .. "  ·  " .. (rec and rec.zone or "Dun Morogh"))
  local popup = not PetSkillScoutDB or PetSkillScoutDB.rareAlertPopup ~= false
  alert:SetAlpha(popup and 1 or 0.35)
  self.sPreviewNote:SetText(L("previewNote"))
end
