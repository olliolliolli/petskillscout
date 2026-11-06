-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- ElvUI-style interface layout (part of the game skin, Settings > Interface).
-- Builds new pieces instead of only recolouring Blizzard ones:
--   * unit frames: player, target, target of target, pet (flat bars, class /
--     reaction colours, PetSkillScout badge on tameable targets, pet happiness)
--   * action bars: the three bottom bars stacked in the centre, pet and stance
--     bars above, flat square buttons; micro menu and bags moved bottom right
--   * chat panel bottom left with an info row; info bar bottom right
--     (ammo, bags, durability, pet); tooltip anchored above it
--   * square minimap top right with zone text, wheel zoom, XP and pet XP bars
--   * interface font (Noto Sans, Latin + Cyrillic)
-- Rules: everything is built and moved out of combat only (secure buttons
-- are made from Blizzard templates, Blizzard unit frames are parked under a
-- hidden parent, never shown/hidden in combat). Taking the layout back needs
-- /reload, which the addon offers with one click.
local PSS = PetSkillScout
PSS.Layout = {}
local LY = PSS.Layout

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local BTN, GAP = 34, 3

local hider = CreateFrame("Frame")
hider:Hide()
LY.hider = hider
LY.applied = {}
LY.strips = {}

local function L(k) return PSS:L(k) end
local function G(n) local v = _G[n]; return type(v) == "table" and v or nil end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end

local function DB() return PetSkillScoutDB or {} end
local function Part(key)
  local S = PSS.Skin
  return S and S:Wanted() and DB()[key] ~= false
end
function LY:Want(part)
  if part == "bars" then return PSS.Skin and PSS.Skin:BarsWanted() end
  if part == "units" then return Part("skinUnits") end
  if part == "chat" then return Part("skinChat") end
  if part == "minimap" then return Part("skinMinimap") end
  if part == "fonts" then return Part("skinFonts") end
  if part == "plates" then return Part("skinPlates") end
  if part == "party" then return Part("skinParty") and self:Want("units") end
  if part == "bags" then return Part("skinBags") end
end

local function Col(k)
  local c = PSS.Skin and PSS.Skin.colours and PSS.Skin.colours[k]
  return c or {0.1, 0.1, 0.1, 0.9}
end

-- Small building blocks ---------------------------------------------------
-- Backdrops of the layout are re-drawn after every Skin refresh (theme).
LY.bds = {}
local function BD(frame, kind, inset, layer)
  LY.bds[#LY.bds + 1] = {frame, kind, inset, layer}
  if PSS.Skin and PSS.Skin.active then return PSS.Skin:Backdrop(frame, kind, inset, layer) end
end
function LY:Restyle()
  local S = PSS.Skin
  if not (S and S.active) then return end
  for _, b in ipairs(self.bds) do S:Backdrop(b[1], b[2], b[3], b[4]) end
  if self.StyleTabs then pcall(self.StyleTabs, self) end
  if self.SkinMenus then pcall(self.SkinMenus, self) end
  if PSS.Auras and PSS.Auras.on then
    pcall(PSS.Auras.StyleAll, PSS.Auras); pcall(PSS.Auras.Arrange, PSS.Auras); pcall(PSS.Auras.UpdateTarget, PSS.Auras)
  end
  if PSS.Plates and PSS.Plates.on then pcall(PSS.Plates.StyleAll, PSS.Plates) end
end
local function Panel(name, parent, kind)
  local f = CreateFrame("Frame", name, parent or UIParent)
  BD(f, kind or "window")
  return f
end

local function Text(parent, size, justify, layer)
  local t = parent:CreateFontString(nil, layer or "OVERLAY")
  t:SetFont(FONT, size or 11, "OUTLINE")
  t:SetJustifyH(justify or "LEFT")
  if t.SetWordWrap then t:SetWordWrap(false) end
  return t
end

local function Bar(parent)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetStatusBarTexture(FLAT)
  b:SetMinMaxValues(0, 1)
  b:SetValue(1)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(FLAT)
  bg:SetVertexColor(0.06, 0.06, 0.08, 0.9)
  b.bg = bg
  return b
end

-- Park a Blizzard frame for good (until /reload). Out of combat only.
local function Park(f)
  if type(f) ~= "table" then return end
  if f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
  pcall(f.Hide, f)
  pcall(f.SetParent, f, hider)
end
LY.Park = Park

local function Short(n)
  if type(n) ~= "number" then return "" end
  if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
  if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
  return tostring(math.floor(n + 0.5))
end

---------------------------------------------------------------------------
-- Unit frames
---------------------------------------------------------------------------
local units = {}
LY.units = units

local REACTION = {
  {0.78, 0.25, 0.25}, {0.78, 0.25, 0.25}, {0.75, 0.40, 0.20}, {0.85, 0.77, 0.36},
  {0.30, 0.68, 0.30}, {0.30, 0.68, 0.30}, {0.30, 0.68, 0.30}, {0.30, 0.68, 0.30},
}

-- Standard class colours (the same ones every unit frame addon uses).
local CLASS = {
  HUNTER = {0.67, 0.83, 0.45}, WARRIOR = {0.78, 0.61, 0.43}, PALADIN = {0.96, 0.55, 0.73},
  ROGUE = {1.00, 0.96, 0.41}, PRIEST = {1.00, 1.00, 1.00}, SHAMAN = {0.00, 0.44, 0.87},
  MAGE = {0.25, 0.78, 0.92}, WARLOCK = {0.53, 0.53, 0.93}, DRUID = {1.00, 0.49, 0.04},
  DEATHKNIGHT = {0.77, 0.12, 0.23}, MONK = {0.00, 1.00, 0.60}, DEMONHUNTER = {0.64, 0.19, 0.79},
  EVOKER = {0.20, 0.58, 0.50},
}
LY.CLASS = CLASS
local playerClass
local function ClassOf(unit)
  if unit == "player" then
    if not playerClass then
      local _, c = Call(UnitClass, "player")
      playerClass = Plain(c)
    end
    return playerClass
  end
  local _, c = Call(UnitClass, unit)
  return Plain(c)
end

local function ClassColour(unit)
  local class = ClassOf(unit)
  local c = class and CLASS[class]
  if c then return c[1], c[2], c[3] end
  local rc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if rc then return rc.r, rc.g, rc.b end
end

local function HealthColour(unit)
  if unit == "player" or Plain(Call(UnitIsPlayer, unit)) then
    local r, g, b = ClassColour(unit)
    if r then return r, g, b end
  end
  if Plain(Call(UnitIsTapDenied, unit)) then return 0.5, 0.5, 0.5 end
  local react = Plain(Call(UnitReaction, unit, "player"))
  local c = type(react) == "number" and REACTION[react]
  if c then return c[1], c[2], c[3] end
  return 0.30, 0.68, 0.30
end

-- Softer power colours (ElvUI-like) instead of the saturated Blizzard ones.
local POWER = {MANA = {0.31, 0.45, 0.63}, RAGE = {0.78, 0.25, 0.25}, ENERGY = {0.65, 0.63, 0.35},
  FOCUS = {0.71, 0.43, 0.27}, HAPPINESS = {0.0, 0.6, 0.55}, RUNIC_POWER = {0, 0.82, 1}}
local POWER_BY_ID = {[0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [4] = "HAPPINESS"}
local function PowerColour(unit)
  local ptype, token = Call(UnitPowerType, unit)
  token = Plain(token) or POWER_BY_ID[Plain(ptype) or 0]
  local c = token and POWER[token]
  if c then return c[1], c[2], c[3] end
  local b = PowerBarColor and token and PowerBarColor[token]
  if b and b.r then return b.r, b.g, b.b end
  return 0.31, 0.45, 0.63
end

local function NpcID(unit)
  local guid = Plain(Call(UnitGUID, unit))
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

-- One short line for a tameable target: "Tameable · Wolf · Bite 3 · RARE".
function LY:Badge(unit)
  local _, class = Call(UnitClass, "player")
  if Plain(class) ~= "HUNTER" then return nil end
  local npc = NpcID(unit)
  if not npc then return nil end
  local rec = PSS.Atlas and PSS.Atlas:Get(npc)
  local teach
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.npcID == npc and b.ability then teach = b; break end
  end
  if not rec and not teach then return nil end
  local parts = {}
  if rec then
    parts[#parts + 1] = string.format(L("ttTameable"), rec.family and PSS:NameFamily(rec.family) or "?")
  end
  if teach then parts[#parts + 1] = PSS:NameAbility(teach.ability) .. " " .. tostring(teach.rank) end
  if rec and rec.isRare then parts[#parts + 1] = "|cffc79cff" .. L("rareCreature") .. "|r" end
  return table.concat(parts, "  ·  ")
end

local function UpdateHealth(f)
  local u = f.unit
  local cur, max = Call(UnitHealth, u), Call(UnitHealthMax, u)
  if max ~= nil then pcall(f.hp.SetMinMaxValues, f.hp, 0, max) end
  if cur ~= nil then pcall(f.hp.SetValue, f.hp, cur) end
  local text
  local pc, pm = Plain(cur), Plain(max)
  if Plain(Call(UnitIsDeadOrGhost, u)) then
    text = DEAD or "Dead"
  elseif pc and pm then
    text = Short(pc)
    if pm > 0 and pc < pm and f.big then text = text .. "  |cffbbbbbb" .. math.floor(pc / pm * 100 + 0.5) .. "%|r" end
  elseif cur ~= nil and AbbreviateNumbers then
    text = Call(AbbreviateNumbers, cur)
  end
  if f.hpText then pcall(f.hpText.SetText, f.hpText, text or "") end
  local r, g, b = HealthColour(u)
  f.hp:SetStatusBarColor(r, g, b)
end

local function UpdatePower(f)
  if not f.pp then return end
  local u = f.unit
  local cur, max = Call(UnitPower, u), Call(UnitPowerMax, u)
  if max ~= nil then pcall(f.pp.SetMinMaxValues, f.pp, 0, max) end
  if cur ~= nil then pcall(f.pp.SetValue, f.pp, cur) end
  f.pp:SetStatusBarColor(PowerColour(u))
  if f.ppText then
    local pc = Plain(cur)
    pcall(f.ppText.SetText, f.ppText, pc and pc > 0 and Short(pc) or "")
  end
end

local CLASSIF = {elite = "+", rare = " R", rareelite = " R+", worldboss = " B"}
local function UpdateName(f)
  local u = f.unit
  local name = Call(UnitName, u)
  if name ~= nil then pcall(f.name.SetText, f.name, name) end
  -- Bars are class coloured, so names stay white; level carries the colour.
  if f.level then
    local lvl = Plain(Call(UnitLevel, u))
    local cls = Plain(Call(UnitClassification, u))
    local s = (type(lvl) == "number" and lvl > 0) and tostring(lvl) or "??"
    f.level:SetText(s .. (cls and CLASSIF[cls] or ""))
    local c = GetQuestDifficultyColor and type(lvl) == "number" and lvl > 0 and Call(GetQuestDifficultyColor, lvl)
    if c and c.r then f.level:SetTextColor(c.r, c.g, c.b) else f.level:SetTextColor(1, 0.82, 0) end
  end
  if f.badge then
    local b = LY:Badge(u)
    f.badge:SetText(b or "")
    f.badgeBg:SetShown(b ~= nil)
    if PSS.Auras and PSS.Auras.PlaceTargetRow then pcall(PSS.Auras.PlaceTargetRow, PSS.Auras) end
  end
end

local function UpdateStatus(f)
  if f.unit == "player" then
    if f.combat then f.combat:SetShown(InCombat() and true or false) end
    if f.rest then f.rest:SetShown(Plain(Call(IsResting)) and not InCombat() or false) end
  elseif f.unit == "pet" and f.mood then
    local h = PSS.PetCare and select(1, PSS.PetCare:Happiness())
    local c = ({{0.9, 0.25, 0.25}, {0.9, 0.75, 0.25}, {0.35, 0.85, 0.4}})[h or 0]
    if c then f.mood:SetVertexColor(c[1], c[2], c[3], 1); f.mood:Show() else f.mood:Hide() end
    f.moodTip = h and L("happy" .. h) or nil
  end
end

local function UpdatePortrait(f)
  local p = f and f.portrait
  if not p then return end
  if not Plain(Call(UnitExists, f.unit)) then p:Hide(); return end
  p:Show()
  pcall(p.ClearModel, p)
  pcall(p.SetUnit, p, f.unit)
  pcall(p.SetPortraitZoom, p, 1)
  pcall(p.SetCamDistanceScale, p, 1)
  pcall(p.SetPosition, p, 0, 0, 0)
end
LY.UpdatePortrait = UpdatePortrait

local function UpdateUnit(f)
  if not f then return end
  if not (f:IsShown() or f.unit == "player") then return end
  if f.unit ~= "player" and not Plain(Call(UnitExists, f.unit)) then return end
  UpdateHealth(f)
  UpdatePower(f)
  UpdateName(f)
  UpdateStatus(f)
end
LY.UpdateUnit = UpdateUnit

local function UnitOnEnter(self)
  if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) end
  pcall(GameTooltip.SetUnit, GameTooltip, self.unit)
  if self.moodTip then GameTooltip:AddLine(self.moodTip, 0.8, 0.8, 0.8) end
  GameTooltip:Show()
end

local function MakeUnit(unit, w, h, ph, big)
  local name = "PetSkillScoutUF_" .. unit
  local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
  f.unit, f.big = unit, big
  f:SetSize(w, h)
  f:SetFrameStrata("LOW")
  f:SetAttribute("unit", unit)
  f:SetAttribute("type1", "target")
  f:SetAttribute("type2", "togglemenu")
  if f.RegisterForClicks then f:RegisterForClicks("AnyUp") end
  BD(f, "slot", {-1, 1, 1, -1})
  f.hp = Bar(f)
  f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  f.hp:SetHeight(ph > 0 and (h - ph - 1) or h)
  if ph > 0 then
    f.pp = Bar(f)
    f.pp:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.pp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.pp:SetHeight(ph)
  end
  local fs = big and 12 or 10
  f.name = Text(f.hp, fs, "LEFT")
  f.name:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
  f.name:SetPoint("RIGHT", f.hp, "RIGHT", big and -70 or -34, 0)
  f.name:SetTextColor(1, 1, 1)
  f.hpText = Text(f.hp, fs, "RIGHT")
  f.hpText:SetTextColor(1, 1, 1)
  f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -4, 0)
  if big then
    -- Level inside the bar, before the name: nothing above the frame but
    -- the aura rows.
    f.level = Text(f.hp, 11, "LEFT")
    f.level:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
    f.name:ClearAllPoints()
    f.name:SetPoint("LEFT", f.level, "RIGHT", 4, 0)
    f.name:SetPoint("RIGHT", f.hp, "RIGHT", -70, 0)
    if f.pp then
      f.ppText = Text(f.pp, 9, "RIGHT")
      f.ppText:SetTextColor(0.9, 0.9, 0.9)
      f.ppText:SetPoint("RIGHT", f.pp, "RIGHT", -3, 0)
    end
  end
  f:SetScript("OnEnter", UnitOnEnter)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if unit ~= "player" and RegisterUnitWatch then RegisterUnitWatch(f) end
  PSS.HookScript(f, "OnShow", function(self) UpdateUnit(self); UpdatePortrait(self) end)
  -- Visible colours from the first frame on (before any event arrives).
  local r, g, b = HealthColour(unit)
  f.hp:SetStatusBarColor(r, g, b)
  if f.pp then f.pp:SetStatusBarColor(PowerColour(unit)) end
  units[unit] = f
  return f
end

local function BuildUnits()
  local player = MakeUnit("player", 230, 44, 10, true)
  player:SetPoint("BOTTOM", UIParent, "BOTTOM", -250, 240)
  local target = MakeUnit("target", 230, 44, 10, true)
  target:SetPoint("BOTTOM", UIParent, "BOTTOM", 250, 240)
  local tot = MakeUnit("targettarget", 120, 22, 0, false)
  tot:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -6)
  local pet = MakeUnit("pet", 120, 24, 5, false)
  pet:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -6)
  LY:Movable("player", player, "slot_player"); LY:Movable("target", target, "slot_target")
  LY:Movable("targettarget", tot, "slot_tot"); LY:Movable("pet", pet, "slot_pet")
  -- 3D portraits outside the frames (player left, target right).
  for _, def in ipairs({{player, "TOPRIGHT", "TOPLEFT", -5}, {target, "TOPLEFT", "TOPRIGHT", 5}}) do
    local f = def[1]
    local p = CreateFrame("PlayerModel", nil, f)
    p:SetSize(44, 44)
    p:SetPoint(def[2], f, def[3], def[4], 0)
    BD(p, "slot", {-1, 1, 1, -1})
    f.portrait = p
  end
  -- Player: combat and resting marks.
  -- Marks sit on a frame above the 3D portrait (models draw over their own textures).
  local over = CreateFrame("Frame", nil, player.portrait)
  over:SetAllPoints(player.portrait)
  over:SetFrameLevel((player.portrait:GetFrameLevel() or 1) + 3)
  player.combat = over:CreateTexture(nil, "OVERLAY")
  player.combat:SetSize(8, 8); player.combat:SetTexture(FLAT)
  player.combat:SetVertexColor(0.95, 0.25, 0.25, 1)
  player.combat:SetPoint("TOPRIGHT", player.portrait, "TOPRIGHT", -2, -2); player.combat:Hide()
  player.rest = Text(over, 11, "RIGHT")
  player.rest:SetPoint("BOTTOMRIGHT", player.portrait, "BOTTOMRIGHT", -2, 2)
  player.rest:SetText("zZ"); player.rest:SetTextColor(0.6, 0.8, 1); player.rest:Hide()
  -- Target: PetSkillScout badge for tameable beasts.
  target.badgeBg = target:CreateTexture(nil, "BACKGROUND")
  target.badgeBg:SetTexture(FLAT)
  local acc = Col("accent")
  target.badgeBg:SetVertexColor(acc[1] * 0.25, acc[2] * 0.25, acc[3] * 0.25, 0.85)
  target.badgeBg:SetPoint("BOTTOMLEFT", target, "TOPLEFT", -1, 18)
  target.badgeBg:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 1, 18)
  target.badgeBg:SetHeight(16); target.badgeBg:Hide()
  target.badge = Text(target, 10, "CENTER")
  target.badge:SetPoint("LEFT", target.badgeBg, "LEFT", 4, 0)
  target.badge:SetPoint("RIGHT", target.badgeBg, "RIGHT", -4, 0)
  target.badge:SetTextColor(acc[1], acc[2], acc[3])
  -- Pet: happiness strip on the left edge.
  pet.mood = pet:CreateTexture(nil, "OVERLAY")
  pet.mood:SetTexture(FLAT); pet.mood:SetWidth(3)
  pet.mood:SetPoint("TOPRIGHT", pet, "TOPLEFT", -2, 0)
  pet.mood:SetPoint("BOTTOMRIGHT", pet, "BOTTOMLEFT", -2, 0)
  pet.mood:Hide()
  -- Blizzard frames out of the way.
  for _, n in ipairs({"PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "ComboFrame", "FocusFrame"}) do
    Park(G(n))
  end
end

-- Party frames: four flat frames stacked on the left, class coloured.
local function BuildParty()
  local holder = CreateFrame("Frame", "PetSkillScoutPartyHolder", UIParent)
  holder:SetSize(170, 4 * 36 - 6)
  holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -220)
  for i = 1, 4 do
    local f = MakeUnit("party" .. i, 170, 30, 6, false)
    f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * 36)
  end
  LY:Movable("party", holder, "slot_party")
  for i = 1, 4 do Park(G("PartyMemberFrame" .. i)) end
  for _, n in ipairs({"PartyFrame", "PartyMemberBackground"}) do
    Park(G(n))
  end
end

local unitEvents = CreateFrame("Frame")
LY.unitEvents = unitEvents
local UNIT_EVENTS = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE",
  "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_HAPPINESS",
  "PLAYER_TARGET_CHANGED", "UNIT_PET", "UNIT_TARGET", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "UNIT_CLASSIFICATION_CHANGED", "UNIT_MODEL_CHANGED",
  "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_CONNECTION",
  "UNIT_PORTRAIT_UPDATE"}

local function StartUnitEvents()
  for _, e in ipairs(UNIT_EVENTS) do pcall(unitEvents.RegisterEvent, unitEvents, e) end
  unitEvents:SetScript("OnEvent", function(_, event, u)
    if event == "UNIT_MODEL_CHANGED" or event == "UNIT_PORTRAIT_UPDATE" then
      if units[u] then UpdatePortrait(units[u]) end
    elseif event == "PLAYER_TARGET_CHANGED" then
      UpdateUnit(units.target); UpdateUnit(units.targettarget); UpdatePortrait(units.target)
    elseif event == "UNIT_PET" or event == "UNIT_HAPPINESS" then
      UpdateUnit(units.pet)
    elseif event == "UNIT_TARGET" then
      if u == "target" then UpdateUnit(units.targettarget) end
    elseif event:find("^PLAYER_") or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
      for _, f in pairs(units) do UpdateUnit(f) end
    elseif type(u) == "string" and units[u] then
      local f = units[u]
      if event:find("HEALTH") then UpdateHealth(f)
      elseif event:find("POWER") then
        UpdatePower(f)
        if u == "pet" then UpdateStatus(f) end
      else UpdateUnit(f) end
    end
  end)
  local t, slow = 0, 0
  unitEvents:SetScript("OnUpdate", function(_, e)
    t = t + (e or 0)
    if t < 0.3 then return end
    t = 0
    if units.targettarget and units.targettarget:IsShown() then pcall(UpdateUnit, units.targettarget) end
    -- Safety net: some health/power changes have no event on this client.
    slow = slow + 1
    if slow >= 10 then
      slow = 0
      for _, f in pairs(units) do pcall(UpdateUnit, f) end
    end
  end)
  unitEvents.pssKey = "unit frames"
  PSS:Every(unitEvents, 0.3)
  -- The layout is built on PLAYER_ENTERING_WORLD, after that event fired:
  -- draw everything once now.
  for _, f in pairs(units) do pcall(UpdateUnit, f); pcall(UpdatePortrait, f) end
end

-- Cast bar: keep Blizzard's, flat (Skin) and placed above the action bars.
local function PlaceCastBar()
  local cb = G("CastingBarFrame")
  if not cb or InCombat() then return end
  pcall(cb.ClearAllPoints, cb)
  pcall(cb.SetPoint, cb, "BOTTOM", UIParent, "BOTTOM", 0, 168)
end

---------------------------------------------------------------------------
-- Action bars
---------------------------------------------------------------------------
local BAR_ROWS = {
  {"ActionButton", nil},
  {"MultiBarBottomLeftButton", "MultiBarBottomLeft"},
  {"MultiBarBottomRightButton", "MultiBarBottomRight"},
}
local barHolder

local function Shown(name)
  if not name then return true end
  local f = G(name)
  return f and f.IsShown and f:IsShown() and true or false
end

local function PlaceButton(b, size, anchor, x, y)
  if not b then return end
  pcall(b.SetSize, b, size, size)
  pcall(b.ClearAllPoints, b)
  pcall(b.SetPoint, b, "BOTTOMLEFT", anchor, "BOTTOMLEFT", x, y)
end

function LY:LayoutBars()
  if not barHolder or InCombat() then return end
  local width = 12 * BTN + 11 * GAP
  barHolder:SetSize(width, BTN)
  local row = 0
  for _, def in ipairs(BAR_ROWS) do
    if Shown(def[2]) then
      for i = 1, 12 do PlaceButton(G(def[1] .. i), BTN, barHolder, (i - 1) * (BTN + GAP), row * (BTN + GAP)) end
      row = row + 1
    end
  end
  local top = row * (BTN + GAP) + 4
  local small = 30
  -- Stance buttons on the left; the pet bar centred (right aligned when a
  -- stance bar is also there).
  local stance = G("StanceButton1") or G("ShapeshiftButton1")
  local hasStance = stance and stance.IsShown and stance:IsShown()
  local petW = 10 * small + 9 * GAP
  local petX = hasStance and (width - petW) or math.floor((width - petW) / 2)
  for i = 1, 10 do
    PlaceButton(G("PetActionButton" .. i), small, barHolder, petX + (i - 1) * (small + GAP), top)
  end
  for _, prefix in ipairs({"StanceButton", "ShapeshiftButton"}) do
    for i = 1, 10 do PlaceButton(G(prefix .. i), small, barHolder, (i - 1) * (small + GAP), top) end
  end
  self.barTop = top + small
end

local function BuildBars()
  barHolder = CreateFrame("Frame", "PetSkillScoutBarHolder", UIParent)
  LY.barHolderFrame = barHolder
  barHolder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
  -- Blizzard bar extras that would sit on top of the new layout.
  for _, n in ipairs({"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber", "MainMenuExpBar",
    "ReputationWatchBar", "MainMenuBarMaxLevelBar", "MainMenuBarPerformanceBarFrame", "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap", "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer"}) do
    Park(G(n))
  end
  LY:LayoutBars()
  -- Blizzard re-arranges bars when one is toggled; follow it out of combat.
  local function relayoutNow()
    if InCombat() then LY.pendingLayout = true; return end
    pcall(LY.LayoutBars, LY); PlaceCastBar(); pcall(LY.PlaceMenus, LY); pcall(LY.PlaceMinimap, LY)
    if PSS.Auras and PSS.Auras.on then pcall(PSS.Auras.Place, PSS.Auras) end
  end
  local function relayout() PSS:Soon("relayout", relayoutNow) end
  -- Modern bars lay their buttons out themselves (edit mode); redo ours after.
  for _, n in ipairs({"MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "PetActionBar", "StanceBar"}) do
    local f = G(n)
    if f and type(f.UpdateGridLayout) == "function" then PSS.HookSecure(f, "UpdateGridLayout", relayout) end
  end
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", relayout, LY)
  end
  for _, fn in ipairs({"MultiActionBar_Update", "UIParent_ManageFramePositions", "MainMenuBar_UpdateArt"}) do
    if type(_G[fn]) == "function" then
      PSS.HookSecure(fn, relayout)
    end
  end
end

---------------------------------------------------------------------------
-- Chat panel, info bars, menus, tooltip
---------------------------------------------------------------------------
local leftPanel, rightBar
local dts = {}

-- Info slots: equal cells with thin dividers; text aligned per cell
-- (first cell left, last cell right, the rest centred) so the row reads tidy.
-- Info slots: equal cells with thin dividers; text aligned per cell
-- (first cell left, last cell right, the rest centred) so the row reads tidy.
local function ReflowDT(b)
  local parent, i, n = b.slotParent, b.slotIndex, b.slotCount
  local w = (parent:GetWidth() - 8) / n
  b:SetSize(w, 18)
  b:ClearAllPoints()
  b:SetPoint("LEFT", parent, "LEFT", 4 + (i - 1) * w, 0)
  if b.divider then
    b.divider:ClearAllPoints()
    b.divider:SetPoint("CENTER", parent, "LEFT", 4 + (i - 1) * w, 0)
  end
end

local function NewDT(parent, i, n)
  local b = CreateFrame("Button", nil, parent)
  b.slotParent, b.slotIndex, b.slotCount = parent, i, n
  local just = (i == 1 and n > 2) and "LEFT" or ((i == n and n > 2) and "RIGHT" or "CENTER")
  b.text = Text(b, 11, just)
  b.text:SetTextColor(1, 1, 1)
  b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
  b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
  if i > 1 then
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetTexture(FLAT)
    local e = Col("edge")
    d:SetVertexColor(e[1], e[2], e[3], 0.6)
    d:SetSize(1, 12)
    b.divider = d
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(FLAT); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.06)
  if b.RegisterForClicks then b:RegisterForClicks("AnyUp") end
  ReflowDT(b)
  dts[#dts + 1] = b
  return b
end

-- Chat panel sizes (Settings > Interface > Chat size).
local CHAT_SIZES = {s = {380, 230}, m = {440, 290}, l = {520, 350}, xl = {620, 420}}
LY.CHAT_SIZES = CHAT_SIZES
function LY:ChatSize()
  local v = CHAT_SIZES[DB().skinChatSize or "m"] or CHAT_SIZES.m
  return v[1], v[2]
end

local function Hex(c) return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local function Label(k, v)
  return "|cff" .. Hex(Col("accent")) .. k .. "|r " .. v
end

local function FreeSlots()
  local free, total = 0, 0
  local num = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local size = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  for bag = 0, 4 do
    local f, kind = Call(num, bag)
    if type(f) == "number" and (kind == 0 or kind == nil) then
      free = free + f
      total = total + (Call(size, bag) or 0)
    end
  end
  return free, total
end

local function Durability()
  local low
  for slot = 1, 18 do
    local cur, max = Call(GetInventoryItemDurability, slot)
    cur, max = Plain(cur), Plain(max)
    if type(cur) == "number" and type(max) == "number" and max > 0 then
      local p = cur / max
      if not low or p < low then low = p end
    end
  end
  return low
end

local function Money(c)
  c = Plain(c) or 0
  local g, s = math.floor(c / 10000), math.floor((c % 10000) / 100)
  return string.format("%d|cffffd700g|r %d|cffc7c7cfs|r", g, s)
end

function LY:UpdateInfo()
  if not leftPanel then return end
  local d = dts
  -- left: time, performance, gold
  local h, m = Call(GetGameTime)
  local clock = date and date("%H:%M") or (h and string.format("%02d:%02d", h, m)) or ""
  d[1].text:SetText(clock)
  local fps = Plain(Call(GetFramerate)) or 0
  local _, _, home, world = Call(GetNetStats)
  local ms = Plain(world) or Plain(home) or 0
  d[2].text:SetText(Label("fps", math.floor(fps + 0.5)) .. "  " .. Label("ms", ms))
  d[3].text:SetText(Money(Call(GetMoney)))
  -- right: ammo, bags, durability, pet
  self.infoSlow = (self.infoSlow or 0) - 1
  if self.infoSlow > 0 then return end
  self.infoSlow = 5 -- bags, ammo, durability and pet mood change slowly
  local ammo = PSS.Ammo and PSS.Ammo:Count()
  d[4].text:SetText(Label(L("dtAmmo"), ammo and tostring(ammo) or "-"))
  local free, total = FreeSlots()
  d[5].text:SetText(Label(L("dtBags"), free .. "/" .. total))
  local dur = Durability()
  local dc = dur and (dur < 0.25 and "|cffff5555" or (dur < 0.5 and "|cffffcc55" or "")) or ""
  d[6].text:SetText(Label(L("dtDur"), dur and (dc .. math.floor(dur * 100 + 0.5) .. "%|r") or "-"))
  local happy = PSS.PetCare and select(1, PSS.PetCare:Happiness())
  local hc = ({"|cffff5555", "|cffffcc55", "|cff66dd77"})[happy or 0] or ""
  d[7].text:SetText(Label(L("dtPet"), happy and (hc .. L("happy" .. happy) .. "|r") or "-"))
end

local function BuildChat()
  -- Three boxes stacked: chat text, message input, info row.
  leftPanel = CreateFrame("Frame", "PetSkillScoutChatPanel", UIParent)
  leftPanel:SetSize(LY:ChatSize())
  leftPanel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 6, 6)
  leftPanel:SetFrameStrata("BACKGROUND")
  local row = Panel("PetSkillScoutChatInfo", leftPanel, "window")
  row:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMLEFT", 0, 0)
  row:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", 0, 0)
  row:SetHeight(22)
  leftPanel.row = row
  local input = Panel("PetSkillScoutChatInput", leftPanel, "input")
  input:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 4)
  input:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 4)
  input:SetHeight(24)
  leftPanel.input = input
  local box = Panel("PetSkillScoutChatBox", leftPanel, "panel")
  box:SetPoint("BOTTOMLEFT", input, "TOPLEFT", 0, 4)
  box:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", 0, 0)
  leftPanel.box = box
  -- Pixel width is needed before the slots are cut.
  row:SetWidth(leftPanel:GetWidth())
  NewDT(row, 1, 3); NewDT(row, 2, 3); NewDT(row, 3, 3)
  rightBar = Panel("PetSkillScoutInfoBar", UIParent, "window")
  rightBar:SetSize(420, 22)
  rightBar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -6, 6)
  rightBar:SetFrameStrata("BACKGROUND")
  NewDT(rightBar, 1, 4); NewDT(rightBar, 2, 4); NewDT(rightBar, 3, 4); NewDT(rightBar, 4, 4)
  -- clicks
  dts[3]:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
  dts[5]:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
  dts[4]:SetScript("OnClick", function() if PSS.Ammo and PSS.Ammo.Report then PSS.Ammo:Report() end end)
  dts[7]:SetScript("OnClick", function() if PSS.UI and PSS.UI.Open then PSS.UI:Open("pet") end end)
  dts[6]:SetScript("OnClick", function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end)
  local tick = 0
  leftPanel:SetScript("OnUpdate", function(_, e)
    tick = tick + (e or 0)
    if tick < 1 then return end
    tick = 0
    pcall(LY.UpdateInfo, LY)
  end)
  leftPanel.pssKey = "info bar"
  PSS:Every(leftPanel, 1)
  LY:PlaceChat()
end

-- Old chat side buttons (menu bubble, voice, channels, quick join) and the
-- scroll bars go; the mouse wheel still scrolls, Shift-wheel jumps.
local CHAT_PARK = {"ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
  "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton", "FriendsMicroButton", "ChatAlertFrame",
  "GeneralDockManagerOverflowButton"}

local function ParkChatButtons()
  for _, n in ipairs(CHAT_PARK) do Park(G(n)) end
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local p = "ChatFrame" .. i
    local cf = G(p)
    Park(G(p .. "ButtonFrame"))
    for _, k in ipairs({"UpButton", "DownButton", "BottomButton"}) do Park(G(p .. k)); Park(G(p .. "ButtonFrame" .. k)) end
    if cf then
      for _, k in ipairs({"ScrollBar", "ScrollToBottomButton", "buttonFrame"}) do
        if type(cf[k]) == "table" then Park(cf[k]) end
      end
    end
  end
end

-- Chat tabs: a strip above the panel, flat theme tabs, always visible;
-- the selected one in the accent colour with a line under it.
local tabsVisible = setmetatable({}, {__mode = "k"})
local tabBusy = false
local function KeepVisible(tab, a)
  if tabBusy or not LY.applied.chat then return end
  if type(a) == "number" and a < 1 then tabBusy = true; pcall(tab.SetAlpha, tab, 1); tabBusy = false end
end

local function TabSelected(tab, i)
  local cf = G("ChatFrame" .. i)
  local dock = G("GENERAL_CHAT_DOCK") or G("GeneralDockManager")
  if dock and type(FCFDock_GetSelectedWindow) == "function" then
    local w = Call(FCFDock_GetSelectedWindow, dock)
    if w then return w == cf end
  end
  local sel = G("SELECTED_CHAT_FRAME") or G("SELECTED_DOCK_FRAME")
  if sel then return sel == cf end
  return i == 1
end

function LY:StyleTabs()
  if not (leftPanel and self.applied.chat) then return end
  local S = PSS.Skin
  if not (S and S.active) then return end
  local acc, muted = Col("accent"), {0.65, 0.68, 0.75}
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local tab = G("ChatFrame" .. i .. "Tab")
    if tab then
      local selected = TabSelected(tab, i)
      S:Backdrop(tab, selected and "button" or "panel", {1, -3, -1, 1})
      if not tab.pssLine then
        tab.pssLine = tab:CreateTexture(nil, "OVERLAY")
        tab.pssLine:SetTexture(FLAT)
        tab.pssLine:SetHeight(2)
        tab.pssLine:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 2, 2)
        tab.pssLine:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
      end
      tab.pssLine:SetVertexColor(acc[1], acc[2], acc[3], 1)
      tab.pssLine:SetShown(selected and true or false)
      local fs = tab.GetFontString and Call(tab.GetFontString, tab)
      if type(fs) ~= "table" then fs = type(rawget(tab, "Text")) == "table" and tab.Text or G("ChatFrame" .. i .. "TabText") end
      if type(fs) == "table" and fs.SetTextColor then
        pcall(fs.SetFont, fs, FONT, 11, "")
        if selected then fs:SetTextColor(acc[1], acc[2], acc[3]) else fs:SetTextColor(muted[1], muted[2], muted[3]) end
      end
      if not tabsVisible[tab] and hooksecurefunc then
        tabsVisible[tab] = true
        pcall(PSS.HookSecure, tab, "SetAlpha", KeepVisible)
      end
      tabBusy = true; pcall(tab.SetAlpha, tab, 1); tabBusy = false
    end
  end
end

local PlaceDock
function PlaceDock()
  local dock = G("GeneralDockManager")
  if not (dock and leftPanel) or InCombat() then return end
  -- Leave the dock alone while a tab is dragged, and when it is already in
  -- place: re-anchoring it in the middle of the game's own tab layout (for
  -- example when tabs are swapped) left the tabs on top of each other.
  if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
    PSS:Soon("chattabs-later", PlaceDock, 0.5)
    return
  end
  local p, rel, rp, x, y = dock:GetPoint(1)
  if dock:GetNumPoints() == 2 and p == "BOTTOMLEFT" and rel == leftPanel and rp == "TOPLEFT" and x == 0 and y == 2 then return end
  pcall(dock.ClearAllPoints, dock)
  pcall(dock.SetPoint, dock, "BOTTOMLEFT", leftPanel, "TOPLEFT", 0, 2)
  pcall(dock.SetPoint, dock, "BOTTOMRIGHT", leftPanel, "TOPRIGHT", 0, 2)
  pcall(dock.SetHeight, dock, 24)
end

-- A tab dragged out of the dock becomes a loose window on top of the panel
-- (its text then overlaps the main chat). With the theme every window stays
-- in the dock: after a drag, loose windows are docked back (order kept as the
-- player dropped them) and the panel is re-fitted.
local PlaceCombatTab
local function RedockLoose()
  if InCombat() or not LY.applied.chat then return end
  if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
    PSS:Soon("chat-redock", RedockLoose, 0.3)
    return
  end
  local dock = G("GENERAL_CHAT_DOCK") or G("GeneralDockManager")
  for i = 2, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local cf = G("ChatFrame" .. i)
    local tab = G("ChatFrame" .. i .. "Tab")
    local shown = (cf and cf.IsShown and cf:IsShown()) or (tab and tab.IsShown and tab:IsShown())
    if cf and shown and not cf.isDocked and type(FCF_DockFrame) == "function" then
      local n = dock and type(dock.DOCKED_CHAT_FRAMES) == "table" and #dock.DOCKED_CHAT_FRAMES or i
      pcall(FCF_DockFrame, cf, n + 1, true)
    end
  end
  PlaceDock()
  pcall(LY.FitChatFrame, LY)
  pcall(LY.StyleTabs, LY)
  pcall(PlaceCombatTab)
end
LY.RedockLoose = RedockLoose

-- Right edge of the tab strip: Hunter Network, then Combat Log in the corner.
-- They are kept last in the dock (so no other tab is chained to them) and
-- anchored from the dock's right edge.
local combatBusy = false
function PlaceCombatTab()
  if combatBusy or InCombat() or not LY.applied.chat then return end
  if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then return end
  local dock = G("GeneralDockManager")
  if not dock then return end
  local right = {}
  local net = PSS.NetChat and PSS.NetChat.Frame and PSS.NetChat:Frame()
  -- Our network window may have been left as a loose window (its tab then
  -- floats over the chat): put it into the dock first.
  if net and not net.isDocked and net ~= G("ChatFrame2") and type(FCF_DockFrame) == "function" then
    local n = type(dock.DOCKED_CHAT_FRAMES) == "table" and #dock.DOCKED_CHAT_FRAMES or 1
    combatBusy = true
    pcall(FCF_DockFrame, net, n + 1, false)
    combatBusy = false
  end
  if net and net.isDocked and net ~= G("ChatFrame2") then right[#right + 1] = net end
  local combat = G("ChatFrame2")
  if combat and combat.isDocked then right[#right + 1] = combat end
  if #right == 0 then return end
  combatBusy = true
  local list = type(dock.DOCKED_CHAT_FRAMES) == "table" and dock.DOCKED_CHAT_FRAMES
  if list and type(FCF_DockFrame) == "function" then
    for k, cf in ipairs(right) do
      if list[#list - #right + k] ~= cf then
        for _, f in ipairs(right) do pcall(FCF_DockFrame, f, #list + 1, false) end
        break
      end
    end
  end
  -- Each tab is anchored to the dock itself (not to the next tab): the tabs
  -- live in the dock's scroll strip, and a tab-to-tab anchor could leave a tab
  -- floating over the chat.
  local x = 0
  for k = #right, 1, -1 do
    local tab = G(right[k]:GetName() .. "Tab")
    if tab then
      -- Docked tabs live in the dock's clipped scroll strip; out at the right
      -- edge they were cut off (invisible). Parent them to the dock itself.
      if tab.GetParent and tab:GetParent() ~= dock then pcall(tab.SetParent, tab, dock) end
      if tab.SetFrameLevel and dock.GetFrameLevel then pcall(tab.SetFrameLevel, tab, dock:GetFrameLevel() + 5) end
      if tab.Show then pcall(tab.Show, tab) end
      if tab.SetAlpha then pcall(tab.SetAlpha, tab, 1) end
      pcall(tab.ClearAllPoints, tab)
      pcall(tab.SetPoint, tab, "BOTTOMRIGHT", dock, "BOTTOMRIGHT", -x, 0)
      local w = tab.GetWidth and tab:GetWidth() or 0
      if not w or w < 20 then w = 90 end
      x = x + w + 2
    end
  end
  combatBusy = false
end
LY.PlaceCombatTab = PlaceCombatTab

local chatHooked = false
local function HookChat()
  if chatHooked or not hooksecurefunc then return end
  chatHooked = true
  for _, fn in ipairs({"FCFDock_UpdateTabs", "FCF_DockUpdate"}) do
    if type(_G[fn]) == "function" then PSS.HookSecure(fn, function() pcall(PlaceCombatTab) end) end
  end
  for _, fn in ipairs({"FCF_StopDragging", "FCF_UnDockFrame"}) do
    if type(_G[fn]) == "function" then
      PSS.HookSecure(fn, function() PSS:Soon("chat-redock", RedockLoose, 0.2) end)
    end
  end
  for _, fn in ipairs({"FCF_DockUpdate", "FCFTab_UpdateColors", "FCF_Tab_OnClick", "FCF_OpenNewWindow",
    "FCF_Close", "FCFDock_SelectWindow", "FCF_SelectDockFrame"}) do
    if type(_G[fn]) == "function" then
      PSS.HookSecure(fn, function()
        PSS:Soon("chattabs", function()
          if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then return end -- dragging a tab
          PlaceDock(); pcall(LY.StyleTabs, LY); pcall(PlaceCombatTab)
        end)
      end)
    end
  end
end

-- Chat text inside the top box (info 22 + input 24 + two gaps below it).
local fitting = false
function LY:FitChatFrame()
  local cf = G("ChatFrame1")
  if not (cf and leftPanel and self.applied.chat) or fitting then return end
  if InCombat() then self.pendingLayout = true; return end
  local w, h = self:ChatSize()
  fitting = true
  pcall(cf.ClearAllPoints, cf)
  pcall(cf.SetPoint, cf, "BOTTOMLEFT", leftPanel.box or leftPanel, "BOTTOMLEFT", 8, 6)
  pcall(cf.SetSize, cf, w - 16, h - 54 - 12)
  if cf.SetClampRectInsets then pcall(cf.SetClampRectInsets, cf, 0, 0, 0, 0) end
  fitting = false
end

-- The game (Edit Mode, saved chat window size) can put its own size back
-- later, and the text then runs above the panel. Re-fit after any change.
local chatSizeHooked = false
function LY:HookChatFrameSize(cf)
  if chatSizeHooked or not hooksecurefunc then return end
  chatSizeHooked = true
  local function again()
    if fitting then return end
    PSS:Soon("chatfit", function()
      -- A tab is being dragged: the game moves the window itself; fit after.
      if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        PSS:Soon("chatfit-later", function() LY:FitChatFrame() end, 0.5)
        return
      end
      LY:FitChatFrame()
    end, 0.05)
  end
  for _, m in ipairs({"SetSize", "SetHeight", "SetWidth", "SetPoint"}) do
    if type(cf[m]) == "function" then pcall(PSS.HookSecure, cf, m, again) end
  end
end

function LY:PlaceChat()
  if not leftPanel or InCombat() then return end
  local cf = G("ChatFrame1")
  if cf then
    -- Tabs live above the panel now, so the text gets the full height.
    local w, h = self:ChatSize()
    pcall(leftPanel.SetSize, leftPanel, w, h)
    if leftPanel.row then
      pcall(leftPanel.row.SetWidth, leftPanel.row, w)
      for i = 1, 3 do if dts[i] then pcall(ReflowDT, dts[i]) end end
    end
    self:FitChatFrame()
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
    self:HookChatFrameSize(cf)
  end
  ParkChatButtons()
  PlaceDock()
  HookChat()
  pcall(self.StyleTabs, self)
  pcall(PlaceCombatTab)
  PSS:Soon("chat-redock", RedockLoose, 1)
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local eb = G("ChatFrame" .. i .. "EditBox")
    if eb then
      -- Inside the input box between the chat and the info row.
      local slot = leftPanel.input or leftPanel.row
      pcall(eb.ClearAllPoints, eb)
      pcall(eb.SetPoint, eb, "TOPLEFT", slot, "TOPLEFT", 0, 0)
      pcall(eb.SetPoint, eb, "BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 0)
      self:HookEditBox(eb)
    end
  end
end

-- The edit box is a solid theme box above the info row, shown only while
-- typing; the info row always stays visible.
local ebHooked = setmetatable({}, {__mode = "k"})
local ebBusy = false
local function Typing(eb)
  local ok, f = pcall(eb.HasFocus, eb)
  return ok and f and eb:IsShown() and true or false
end

function LY:UpdateEditBoxes()
  if not leftPanel then return end
  local typing = false
  for eb in pairs(ebHooked) do
    local t = Typing(eb)
    typing = typing or t
    ebBusy = true
    pcall(eb.SetAlpha, eb, t and 1 or 0)
    ebBusy = false
  end
  for i = 1, 3 do if dts[i] then dts[i]:SetAlpha(1) end end
  -- The input box lights up (accent border) while you type.
  local S = PSS.Skin
  local bd = S and leftPanel.input and S.BackdropOf and S:BackdropOf(leftPanel.input)
  if bd then
    local e = typing and Col("accent") or Col("edge")
    for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(e[1], e[2], e[3], 1) end
  end
end

function LY:HookEditBox(eb)
  if ebHooked[eb] then return end
  ebHooked[eb] = true
  BD(eb, "input", {0, 0, 0, 0})
  local slot = leftPanel and (leftPanel.input or leftPanel.row)
  if slot and eb.SetFrameLevel then
    pcall(eb.SetFrameLevel, eb, (slot:GetFrameLevel() or 1) + 10)
  end
  local function update() pcall(LY.UpdateEditBoxes, LY) end
  for _, sc in ipairs({"OnShow", "OnHide", "OnEditFocusGained", "OnEditFocusLost"}) do
    pcall(PSS.HookScript, eb, sc, update)
  end
  if hooksecurefunc then
    pcall(PSS.HookSecure, eb, "SetAlpha", function(_, a)
      if ebBusy then return end
      local want = Typing(eb) and 1 or 0
      if a ~= want then ebBusy = true; pcall(eb.SetAlpha, eb, want); ebBusy = false end
    end)
  end
  update()
end

-- Micro menu and bag buttons above the right info bar.
-- Bags right above the info bar, micro menu above the bags (both right
-- aligned), so they never overlap each other or the bar.
function LY:PlaceMenus()
  if not rightBar or InCombat() then return end
  pcall(self.SkinMenus, self)
  local bags = G("BagsBar") or G("MainMenuBarBackpackButton")
  local micro = G("MicroMenuContainer") or G("MicroMenu") or G("CharacterMicroButton")
  local below = rightBar
  -- Screen position (UIParent) right above the info bar: the game's own bars
  -- must not be anchored to addon frames (their layout runs in combat).
  local k = (rightBar:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  local barRight, barTop = rightBar:GetRight(), rightBar:GetTop()
  if not (barRight and barTop) then
    PSS:Soon("place-menus", function() LY:PlaceMenus() end, 1) -- not laid out yet
    return
  end
  local nextTop = barTop * k + 4
  if bags then
    pcall(bags.ClearAllPoints, bags)
    pcall(bags.SetPoint, bags, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", barRight * k, nextTop)
    local h = Plain(bags.GetHeight and bags:GetHeight())
    local bk = (bags:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    if type(h) == "number" then nextTop = nextTop + h * bk + 4 end
    below = bags
  end
  if micro then
    pcall(micro.ClearAllPoints, micro)
    if micro == G("CharacterMicroButton") then
      -- Classic: the first button leads a chain growing to the right.
      pcall(micro.SetPoint, micro, "BOTTOMLEFT", rightBar, "TOPLEFT", 0, (below ~= rightBar and 44 or 4))
    else
      -- Modern micro menu: the game re-lays it out in combat (level up, new
      -- spells). Anchored to our frames, that layout was blocked
      -- (MicroMenuContainer:SetPointBase), so it gets a screen position on
      -- UIParent instead, computed from the bag row / info bar.
      pcall(micro.SetPoint, micro, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", barRight * k, nextTop)
    end
  end
end

-- Micro menu and bag buttons in the theme: stock tile art faded, square
-- theme border per button, cropped bag icons, same size for all bags, a
-- flat strip behind each row.
local menuSkinned = setmetatable({}, {__mode = "k"})
local function FadeKeys(b, keys)
  local S = PSS.Skin
  for _, k in ipairs(keys) do
    local r = type(b[k]) == "table" and b[k] or nil
    if r and r.SetAlpha and S then S.Fade(r) end
  end
end

local function SkinMicroButton(b)
  local S = PSS.Skin
  if type(b) ~= "table" or not (S and S.active) then return end
  FadeKeys(b, {"Background", "PushedBackground", "FlashBorder", "FlashContent", "Shadow"})
  local bd = S:Backdrop(b, "slot", {2, -4, -2, 2}, "OVERLAY")
  if bd and bd.bg.SetDrawLayer then pcall(bd.bg.SetDrawLayer, bd.bg, "BACKGROUND", -8) end
  menuSkinned[b] = true
end

local function SkinBagButton(b, size)
  local S = PSS.Skin
  if type(b) ~= "table" or not (S and S.active) then return end
  local name = b.GetName and b:GetName()
  if b.GetNormalTexture then
    local nt = Call(b.GetNormalTexture, b)
    if type(nt) == "table" then S.Fade(nt) end
  end
  FadeKeys(b, {"IconBorder", "IconOverlay", "CircleMask", "Background", "SlotHighlightTexture"})
  local icon = (type(b.icon) == "table" and b.icon) or (type(b.Icon) == "table" and b.Icon) or (name and G(name .. "IconTexture"))
  if icon then
    if icon.SetTexCoord then pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92) end
    if icon.RemoveMaskTexture and type(b.CircleMask) == "table" then pcall(icon.RemoveMaskTexture, icon, b.CircleMask) end
    if not InCombat() then
      pcall(icon.ClearAllPoints, icon)
      pcall(icon.SetPoint, icon, "TOPLEFT", b, "TOPLEFT", 1, -1)
      pcall(icon.SetPoint, icon, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    end
  end
  -- The backpack is drawn bigger than the bags: scale it to the same size.
  if size and not InCombat() then
    local w = Plain(b.GetWidth and b:GetWidth())
    if type(w) == "number" and w > size + 2 then pcall(b.SetScale, b, size / w) end
  end
  local count = (type(b.Count) == "table" and b.Count) or (name and G(name .. "Count"))
  if count and count.SetFont then pcall(count.SetFont, count, FONT, 10, "OUTLINE") end
  local bd = S:Backdrop(b, "slot", {0, 0, 0, 0}, "OVERLAY")
  if bd and bd.bg.SetDrawLayer then pcall(bd.bg.SetDrawLayer, bd.bg, "BACKGROUND", -8) end
  menuSkinned[b] = true
end

function LY:SkinMenus()
  local S = PSS.Skin
  if not (S and S.active and self.applied.chat) then return end
  -- Micro menu.
  local micro = G("MicroMenu") or G("MicroMenuContainer")
  local list = {}
  if micro then
    for _, c in ipairs({micro:GetChildren()}) do
      if c.GetObjectType and c:GetObjectType() == "Button" then list[#list + 1] = c end
    end
  end
  if #list == 0 and type(MICRO_BUTTONS) == "table" then
    for _, n in ipairs(MICRO_BUTTONS) do if G(n) then list[#list + 1] = G(n) end end
  end
  for _, b in ipairs(list) do pcall(SkinMicroButton, b) end
  -- Bags.
  local bagSize = 30
  local first = G("CharacterBag0Slot")
  if first then
    local w = Plain(first.GetWidth and first:GetWidth())
    if type(w) == "number" and w > 10 then bagSize = w end
  end
  for _, n in ipairs({"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton"}) do
    pcall(SkinBagButton, G(n), bagSize)
  end
  local toggle = G("BagBarExpandToggle")
  if toggle then FadeKeys(toggle, {"Background"}) end
  -- Flat strips behind both rows, container art faded.
  for _, n in ipairs({"MicroMenuContainer", "BagsBar"}) do
    local f = G(n)
    if f and f.GetRegions then
      -- The strip is a separate frame behind the row. Nothing is created on the
      -- game's frame itself: its Layout() runs in combat and would read our
      -- textures, which makes the game block SetSize / SetPoint.
      local strip = self.strips[n]
      if not strip then
        strip = CreateFrame("Frame", nil, UIParent)
        strip:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
        strip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
        BD(strip, "panel")
        self.strips[n] = strip
      end
      pcall(strip.SetFrameStrata, strip, f:GetFrameStrata())
      pcall(strip.SetFrameLevel, strip, math.max(0, (f:GetFrameLevel() or 1) - 1))
      strip:Show()
      for _, r in ipairs({f:GetRegions()}) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then S.Fade(r) end
      end
    end
  end
end

local function TooltipAnchor(tt)
  if not (rightBar and LY.applied.chat) then return end
  pcall(tt.ClearAllPoints, tt)
  pcall(tt.SetPoint, tt, "BOTTOMRIGHT", rightBar, "TOPRIGHT", 0, 70)
end

-- Item quality colour on the tooltip border.
local function TooltipQuality(tt)
  local S = PSS.Skin
  local bd = S and S.BackdropOf and S:BackdropOf(tt)
  if not (bd and S.active) then return end
  local e = Col("edge")
  local _, link = Call(tt.GetItem, tt)
  link = Plain(link)
  if type(link) == "string" then
    local q = Plain(select(3, Call(GetItemInfo, link)))
    local c = type(q) == "number" and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then e = {c.r, c.g, c.b, 1} end
  end
  for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(e[1], e[2], e[3], 1) end
end

local function BuildChatHooks()
  if type(GameTooltip_SetDefaultAnchor) == "function" then
    PSS.HookSecure("GameTooltip_SetDefaultAnchor", function(tt) if LY.applied.chat then TooltipAnchor(tt) end end)
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, PSS:Timed("item tooltip (theme)", function(tt) pcall(TooltipQuality, tt) end))
  elseif GameTooltip and GameTooltip.HookScript then
    pcall(PSS.HookScript, GameTooltip, "OnTooltipSetItem", function(tt) pcall(TooltipQuality, tt) end)
  end
  if GameTooltip and GameTooltip.HookScript then
    PSS.HookScript(GameTooltip, "OnTooltipCleared", function(tt)
      local S = PSS.Skin
      local bd = S and S.BackdropOf and S:BackdropOf(tt)
      if bd and S.active then
        local e = Col("edge")
        for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(e[1], e[2], e[3], 1) end
      end
    end)
  end
  for _, fn in ipairs({"MoveMicroButtons", "UpdateMicroButtonsParent", "UpdateMicroButtons"}) do
    if type(_G[fn]) == "function" then
      PSS.HookSecure(fn, function() PSS:Soon("menus", function() if not InCombat() then pcall(LY.PlaceMenus, LY) end end) end)
    end
  end
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------
local xpBar, petXpBar, zoneText

local function UpdateXP()
  if not xpBar then return end
  local cur, max = Plain(Call(UnitXP, "player")), Plain(Call(UnitXPMax, "player"))
  local lvl = Plain(Call(UnitLevel, "player")) or 0
  local maxLvl = (GetMaxPlayerLevel and Call(GetMaxPlayerLevel)) or MAX_PLAYER_LEVEL or 60
  if type(cur) == "number" and type(max) == "number" and max > 0 and lvl < maxLvl then
    xpBar:SetMinMaxValues(0, max); xpBar:SetValue(cur)
    local rest = Plain(Call(GetXPExhaustion)) or 0
    xpBar.rested:SetMinMaxValues(0, max); xpBar.rested:SetValue(math.min(max, cur + rest))
    local resting = Plain(Call(IsResting)) and true or false
    local pct = math.floor(rest / max * 100 + 0.5)
    local lines = {
      {string.format(L("xpLine"), Short(cur), Short(max), math.floor(cur / max * 100)), 1, 1, 1},
    }
    if rest > 0 then
      lines[#lines + 1] = {string.format(L("xpRested"), Short(rest), pct), 0.35, 0.7, 1}
      lines[#lines + 1] = {L("xpRestedHint"), 0.7, 0.7, 0.7}
    else
      lines[#lines + 1] = {L("xpRestedNone"), 0.7, 0.7, 0.7}
    end
    if resting then lines[#lines + 1] = {L("xpResting"), 0.6, 0.9, 0.6} end
    xpBar.tipLines = lines
    -- Rested shown on the bar itself (the game's own colour code): the XP
    -- fill turns blue while you have rested XP (purple without), and the
    -- rested part ahead of it is a light blue segment.
    if rest > 0 then
      xpBar:SetStatusBarColor(0.20, 0.45, 0.95)
      xpBar.rested:SetStatusBarColor(0.45, 0.80, 1.0, resting and 0.85 or 0.6)
    else
      xpBar:SetStatusBarColor(0.58, 0.35, 0.85)
      xpBar.rested:SetValue(cur)
    end
    xpBar.restedOn = rest > 0
    xpBar:Show()
  else
    xpBar:Hide()
  end
  local pc, pm = Call(GetPetExperience)
  pc, pm = Plain(pc), Plain(pm)
  if type(pc) == "number" and type(pm) == "number" and pm > 0 then
    petXpBar:SetMinMaxValues(0, pm); petXpBar:SetValue(pc)
    petXpBar.tip = string.format("%s XP %s / %s  (%d%%)", L("dtPet"), Short(pc), Short(pm), math.floor(pc / pm * 100))
    petXpBar:Show()
  else
    petXpBar:Hide()
  end
  -- Max level hides the bar: the buff rows move down into its place.
  if PSS.Auras and PSS.Auras.on then pcall(PSS.Auras.Arrange, PSS.Auras) end
end

local function UpdateZone()
  if not zoneText then return end
  local z = Call(GetMinimapZoneText) or ""
  zoneText:SetText(z)
  local pvp = Plain(Call(GetZonePVPInfo))
  local c = ({sanctuary = {0.41, 0.8, 0.94}, friendly = {0.1, 1, 0.1}, hostile = {1, 0.1, 0.1},
    contested = {1, 0.7, 0}, arena = {1, 0.1, 0.1}})[pvp or ""] or {1, 0.9, 0.7}
  zoneText:SetTextColor(c[1], c[2], c[3])
end

local function XPBarOnEnter(self)
  if not (self.tip or self.tipLines) then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  if self.tipLines then
    for i, l in ipairs(self.tipLines) do
      if i == 1 then GameTooltip:SetText(l[1], l[2], l[3], l[4]) else GameTooltip:AddLine(l[1], l[2], l[3], l[4], true) end
    end
  else
    GameTooltip:SetText(self.tip, 1, 1, 1)
  end
  GameTooltip:Show()
end

-- Every addon button on the minimap edge: projected onto the square edge
-- (some addons place their buttons on a circle themselves), round rims
-- faded and a square border added. Repeated every 2 s, out of combat, not
-- while a button is being dragged.
local mmKeep = {}
local mmHolder
LY.mmKeep = mmKeep

local function IsDragging(b)
  if b.isMoving or b.isMouseDown or b.dragging then return true end
  return IsMouseButtonDown and Plain(Call(IsMouseButtonDown, "LeftButton")) and b.IsMouseOver and Plain(Call(b.IsMouseOver, b)) or false
end

-- Positions compared in screen pixels (effective scale), offsets set in the
-- button's own units.
local function SquareButton(b, mm, cx, cy, half)
  if mmKeep[b] or not b.GetCenter or not (b.IsShown and b:IsShown()) then return end
  if IsDragging(b) then return end
  local bx, by = b:GetCenter()
  if not bx then return end
  local bes = b.GetEffectiveScale and b:GetEffectiveScale() or 1
  local dx, dy = bx * bes - cx, by * bes - cy
  local m = math.max(math.abs(dx), math.abs(dy))
  if m < half * 0.55 then return end -- a pin inside the map, not an edge button
  local tx, ty = dx / m * half, dy / m * half
  if math.abs(tx - dx) > 1.5 or math.abs(ty - dy) > 1.5 then
    pcall(b.ClearAllPoints, b)
    pcall(b.SetPoint, b, "CENTER", mm, "CENTER", tx / bes, ty / bes)
  end
end

-- Addon button bar: a vertical strip left of the minimap that holds every
-- addon minimap button (LibDBIcon ones, buttons named "...Minimap...Button",
-- our own). Map pins and the Blizzard tracking / mail buttons are not
-- touched. More buttons than fit the minimap height wrap into a second
-- column. Off (Settings > Interface): buttons follow the square edge.
local BAR_BTN, BAR_GAP = 28, 3
local barButtons = {}
LY.barButtons = barButtons

local function IsAddonButton(c, lib)
  if mmKeep[c] or c == mmHolder then return false end
  if c == G("PetSkillScoutMinimapButton") then return true end
  if lib and lib.objects then
    for _, b in pairs(lib.objects) do if b == c then return true end end
  end
  local name = c.GetName and c:GetName()
  if type(name) ~= "string" then return false end
  if name:find("^LibDBIcon") then return true end
  return name:find("[Mm]inimap") ~= nil and (name:find("[Bb]utton") ~= nil or name:find("Icon") ~= nil)
    and not name:find("^MiniMap") and not name:find("^Minimap")
end

function LY:ButtonBar()
  local mm = G("Minimap")
  if not (mm and mmHolder) then return nil end
  if not self.bar then
    local bar = CreateFrame("Frame", "PetSkillScoutButtonBar", UIParent)
    bar:SetFrameStrata("LOW")
    BD(bar, "panel", {-3, 3, 3, -3})
    self.bar = bar
  end
  return self.bar
end

function LY:ArrangeButtonBar()
  local mm = G("Minimap")
  if not (mm and self.applied.minimap) or InCombat() then return end
  local bar = self:ButtonBar()
  if not bar then return end
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  local list = {}
  for _, root in ipairs({mm, G("MinimapBackdrop"), G("MinimapCluster"), bar}) do
    for _, c in ipairs({root:GetChildren()}) do
      if c.IsShown and c:IsShown() and IsAddonButton(c, lib) then list[#list + 1] = c end
    end
  end
  table.sort(list, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
  local perCol = math.max(1, math.floor((self:MinimapSize() + BAR_GAP) / (BAR_BTN + BAR_GAP)))
  local cols = math.max(1, math.ceil(#list / perCol))
  for i, b in ipairs(list) do
    local col, row = math.floor((i - 1) / perCol), (i - 1) % perCol
    if b:GetParent() ~= bar then pcall(b.SetParent, b, bar) end
    pcall(b.ClearAllPoints, b)
    pcall(b.SetPoint, b, "TOPRIGHT", bar, "TOPRIGHT", -col * (BAR_BTN + BAR_GAP), -row * (BAR_BTN + BAR_GAP))
    pcall(b.SetScale, b, BAR_BTN / math.max(20, Plain(b:GetWidth()) or BAR_BTN))
    barButtons[b] = true
  end
  if not self:Saved("buttons") then bar:ClearAllPoints() end
  if not self:Saved("buttons") then bar:SetPoint("TOPRIGHT", mmHolder, "TOPLEFT", -8, 0) end
  bar:SetSize(cols * (BAR_BTN + BAR_GAP) - BAR_GAP, math.min(#list, perCol) * (BAR_BTN + BAR_GAP) - BAR_GAP)
  if #list > 0 then bar:Show() else bar:Hide() end
end

function LY:SquareMinimapButtons()
  local mm = G("Minimap")
  if not (mm and self.applied.minimap) or InCombat() then return end
  if DB().skinMinimapBar ~= false then return self:ArrangeButtonBar() end
  local mes = mm.GetEffectiveScale and mm:GetEffectiveScale() or 1
  local cx, cy = mm:GetCenter()
  if not cx then return end
  cx, cy = cx * mes, cy * mes
  local half = (mm:GetWidth() or 176) / 2 * mes
  local roots = {mm, G("MinimapBackdrop"), G("MinimapCluster")}
  for _, root in ipairs(roots) do
    if root then
      for _, c in ipairs({root:GetChildren()}) do
        local t = c.GetObjectType and c:GetObjectType()
        if (t == "Button" or t == "Frame") and c ~= mmHolder then
          local w = c.GetWidth and c:GetWidth() or 0
          if w > 10 and w <= 40 and (t == "Button" or (c.IsMouseEnabled and c:IsMouseEnabled())) then
            SquareButton(c, mm, cx, cy, half)
          end
        end
      end
    end
  end
end

-- Square-minimap aware placement of LibDBIcon buttons and our own button.
function LY:RefreshMinimapButtons()
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  if lib and lib.GetButtonList then
    for _, name in ipairs(lib:GetButtonList() or {}) do pcall(lib.Refresh, lib, name) end
  end
  if PSS.PlaceMinimapButton then pcall(PSS.PlaceMinimapButton) end
end

function LY:MinimapSize()
  local v = tonumber(DB().skinMinimapSize)
  if v and v >= 120 and v <= 320 then return v end
  return 176
end

function LY:PlaceMinimap()
  local mm = G("Minimap")
  if not (mm and mmHolder) or InCombat() then return end
  if mm.GetParent and mm:GetParent() ~= mmHolder then pcall(mm.SetParent, mm, mmHolder) end
  pcall(mm.ClearAllPoints, mm)
  pcall(mm.SetPoint, mm, "CENTER", mmHolder, "CENTER", 0, 0)
  local size = self:MinimapSize()
  pcall(mmHolder.SetSize, mmHolder, size, size)
  pcall(mm.SetSize, mm, size, size)
  if zoneText then pcall(zoneText.SetWidth, zoneText, size - 10) end
  if mm.SetMaskTexture then pcall(mm.SetMaskTexture, mm, FLAT) end
  -- The rings around quest / archaeology / task areas are drawn for a round
  -- minimap; with the square mask they show as a stray oval. Hide only the
  -- rings, the areas themselves stay.
  for _, m in ipairs({"SetQuestBlobRingScalar", "SetArchBlobRingScalar", "SetTaskBlobRingScalar"}) do
    if type(mm[m]) == "function" then pcall(mm[m], mm, 0) end
  end
  for _, m in ipairs({"SetQuestBlobRingAlpha", "SetArchBlobRingAlpha", "SetTaskBlobRingAlpha"}) do
    if type(mm[m]) == "function" then pcall(mm[m], mm, 0) end
  end
  -- The map picture keeps its old size until the zoom changes: nudge it.
  local function nudge()
    local z = Plain(Call(mm.GetZoom, mm)) or 0
    local levels = Plain(Call(mm.GetZoomLevels, mm)) or 5
    pcall(mm.SetZoom, mm, z > 0 and z - 1 or math.min(levels - 1, z + 1))
    pcall(mm.SetZoom, mm, z)
  end
  nudge()
  if C_Timer and C_Timer.After then C_Timer.After(0.2, function() if not InCombat() then nudge() end end) end
  if self.SquareMinimapButtons then pcall(self.SquareMinimapButtons, self) end
end

-- Small Blizzard minimap buttons kept, moved into the square corners.
local MM_KEEP = {
  {{"Tracking"}, {"MiniMapTrackingFrame", "MiniMapTracking", "MiniMapTrackingButton"}, "TOPLEFT", 2, -2},
  {{"IndicatorFrame"}, {"MiniMapMailFrame"}, "TOPRIGHT", -2, -2},
  {{"InstanceDifficulty"}, {"MiniMapInstanceDifficulty"}, "BOTTOMLEFT", 2, 2},
  {{}, {"MiniMapBattlefieldFrame", "QueueStatusButton", "QueueStatusMinimapButton"}, "BOTTOMRIGHT", -2, 2},
}

local function BuildMinimap()
  local mm = G("Minimap")
  if not mm then return end
  local mc = G("MinimapCluster")
  mmHolder = CreateFrame("Frame", "PetSkillScoutMinimapHolder", UIParent)
  mmHolder:SetSize(LY:MinimapSize(), LY:MinimapSize())
  mmHolder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -8)
  mmHolder:SetFrameStrata("LOW")
  LY:PlaceMinimap()
  -- Round art, zone bar, clock, zoom buttons, calendar.
  for _, n in ipairs({"MinimapZoomIn", "MinimapZoomOut", "MinimapToggleButton", "MiniMapWorldMapButton",
    "MinimapBorderTop", "MinimapZoneTextButton", "GameTimeFrame", "MinimapNorthTag", "MinimapCompassTexture",
    "TimeManagerClockButton", "ExpansionLandingPageMinimapButton", "MinimapBackdrop"}) do
    Park(G(n))
  end
  for _, k in ipairs({"ZoomIn", "ZoomOut", "ZoomHitArea"}) do
    if type(mm[k]) == "table" then Park(mm[k]) end
  end
  if mc then
    for _, k in ipairs({"BorderTop", "ZoneTextButton"}) do
      if type(mc[k]) == "table" then Park(mc[k]) end
    end
  end
  for _, def in ipairs(MM_KEEP) do
    local f
    for _, k in ipairs(def[1]) do if mc and type(mc[k]) == "table" then f = mc[k] end end
    if not f then for _, n in ipairs(def[2]) do f = f or G(n) end end
    if f then
      mmKeep[f] = true
      pcall(f.SetParent, f, mm)
      pcall(f.ClearAllPoints, f)
      pcall(f.SetPoint, f, def[3], mm, def[3], def[4], def[5])
      pcall(f.SetScale, f, 0.85)
      pcall(f.SetFrameLevel, f, (mm:GetFrameLevel() or 1) + 5)
    end
  end
  -- Blizzard re-lays out the cluster (edit mode, header option): put it back.
  if mc and type(mc.Layout) == "function" then
    PSS.HookSecure(mc, "Layout", function() PSS:Soon("minimap", function() if not InCombat() then pcall(LY.PlaceMinimap, LY) end end) end)
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(1, function() pcall(LY.RefreshMinimapButtons, LY) end)
    C_Timer.After(5, function() pcall(LY.RefreshMinimapButtons, LY) end)
  end
  LY:RefreshMinimapButtons()
  local tick = 0
  mmHolder:SetScript("OnUpdate", function(_, e)
    tick = tick + (e or 0)
    if tick < 10 then return end
    tick = 0
    pcall(LY.SquareMinimapButtons, LY)
  end)
  mmHolder.pssKey = "minimap buttons"
  PSS:Every(mmHolder, 2)
  if mm.EnableMouseWheel then
    mm:EnableMouseWheel(true)
    PSS.HookScript(mm, "OnMouseWheel", function(self, delta)
      local z = Plain(Call(self.GetZoom, self)) or 0
      local levels = Plain(Call(self.GetZoomLevels, self)) or 5
      if delta > 0 then z = math.min(levels - 1, z + 1) else z = math.max(0, z - 1) end
      pcall(self.SetZoom, self, z)
    end)
  end
  zoneText = Text(mm, 11, "CENTER")
  zoneText:SetPoint("TOP", mm, "TOP", 0, -5)
  zoneText:SetWidth(LY:MinimapSize() - 10)
  xpBar = Bar(UIParent)
  xpBar:SetFrameStrata("LOW")
  -- A free row under the map: coordinate addons write their text there.
  xpBar:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 0, -20)
  xpBar:SetPoint("TOPRIGHT", mm, "BOTTOMRIGHT", 0, -20)
  xpBar:SetHeight(8)
  xpBar:SetStatusBarColor(0.58, 0.35, 0.85)
  xpBar.rested = Bar(xpBar)
  xpBar.rested:SetAllPoints()
  xpBar.rested:SetFrameLevel(math.max(0, xpBar:GetFrameLevel() - 1))
  -- Rested part: bright blue segment right after the purple XP.
  xpBar.rested:SetStatusBarColor(0.30, 0.65, 1.0, 0.9)

  -- The rested bar sits under the XP bar, so it carries the dark
  -- background; the XP bar itself is transparent where it is empty.
  xpBar.bg:Hide()
  xpBar.rested.bg:Show()
  BD(xpBar.rested, "slot", {-1, 1, 1, -1}) -- under the XP fill, see above
  xpBar:EnableMouse(true)
  xpBar:SetScript("OnEnter", XPBarOnEnter)
  xpBar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  petXpBar = Bar(UIParent)
  petXpBar:SetFrameStrata("LOW")
  petXpBar:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -4)
  petXpBar:SetPoint("TOPRIGHT", xpBar, "BOTTOMRIGHT", 0, -4)
  petXpBar:SetHeight(6)
  local acc = Col("accent")
  petXpBar:SetStatusBarColor(acc[1], acc[2], acc[3])
  BD(petXpBar, "slot", {-1, 1, 1, -1})
  petXpBar:EnableMouse(true)
  petXpBar:SetScript("OnEnter", XPBarOnEnter)
  petXpBar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local ev = CreateFrame("Frame")
  for _, e in ipairs({"PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UNIT_PET_EXPERIENCE", "UNIT_PET",
    "PLAYER_UPDATE_RESTING",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD"}) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, e)
    if e:find("^ZONE") then UpdateZone() elseif e == "PLAYER_ENTERING_WORLD" then UpdateZone(); UpdateXP() else UpdateXP() end
  end)
  LY.zoneText, LY.xpBar, LY.petXpBar = zoneText, xpBar, petXpBar
  UpdateZone(); UpdateXP()
  LY:PlaceXP()
end
LY.UpdateXP, LY.UpdateZone = UpdateXP, UpdateZone

-- With the unit frames on, the XP bar sits right above the player frame
-- (under the buff rows) and the pet XP bar right under the pet frame;
-- otherwise both stay under the minimap.
LY.xpOffset = 0
function LY:PlaceXP()
  if not (xpBar and petXpBar) or InCombat() then return end
  local player, pet = units.player, units.pet
  local mm = G("Minimap")
  xpBar:ClearAllPoints(); petXpBar:ClearAllPoints()
  if player and self.applied.units then
    xpBar:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 4)
    xpBar:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, 4)
    xpBar:SetHeight(7)
    self.xpOffset = 11
    if pet then
      petXpBar:SetPoint("TOPLEFT", pet, "BOTTOMLEFT", 0, -3)
      petXpBar:SetPoint("TOPRIGHT", pet, "BOTTOMRIGHT", 0, -3)
      petXpBar:SetHeight(4)
    end
  elseif mm then
    xpBar:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 0, -20)
    xpBar:SetPoint("TOPRIGHT", mm, "BOTTOMRIGHT", 0, -20)
    xpBar:SetHeight(8)
    petXpBar:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -4)
    petXpBar:SetPoint("TOPRIGHT", xpBar, "BOTTOMRIGHT", 0, -4)
    petXpBar:SetHeight(6)
    self.xpOffset = 0

  end
  if PSS.Auras and PSS.Auras.on then pcall(PSS.Auras.Arrange, PSS.Auras) end
end

---------------------------------------------------------------------------
-- Fonts: only Font objects are changed (never the global font variables,
-- which Blizzard code reads and which would spread taint).
---------------------------------------------------------------------------
local function ApplyFonts()
  local n = 0
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and obj.GetFont and obj.SetFont and obj.GetObjectType then
      local ok, kind = pcall(obj.GetObjectType, obj)
      if ok and kind == "Font" and not name:find("^PetSkillScout") then
        local ok2, _, size, flags = pcall(obj.GetFont, obj)
        if ok2 and type(size) == "number" and size > 0 then
          if pcall(obj.SetFont, obj, FONT, size, flags or "") then n = n + 1 end
        end
      end
    end
  end
  LY.fontsChanged = n
  LY:ChatFonts()
end

-- Noto Sans looks bigger than the game's Friz Quadrata at the same size, so the
-- chat windows get a slightly smaller size. The size picked in the game (chat tab
-- menu > Font Size) stays the base; only what is drawn is scaled.
local CHAT_FONT_SCALE = 0.72
LY.CHAT_FONT_SCALE = CHAT_FONT_SCALE
function LY:ChatFontSize(base)
  base = tonumber(base) or 14
  return math.max(8, math.floor(base * CHAT_FONT_SCALE + 0.5))
end
local chatFontHooked = false
local chatFontBusy = false
local chatFontFrames = setmetatable({}, {__mode = "k"})
-- The game puts the saved chat font back a moment after login (and when the
-- chat windows update); then the size looked wrong until it was picked again
-- in the menu. Any font change on a chat window now re-applies ours.
local function ChatFontAgain()
  if chatFontBusy then return end
  PSS:Soon("chatfonts", function() LY:ChatFonts() end, 0.1)
end
function LY:ChatFonts()
  if not self.applied.fonts or InCombat() then return end
  chatFontBusy = true
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.SetFont then
      local base
      if FCF_GetChatWindowInfo then
        local ok, _, size = pcall(FCF_GetChatWindowInfo, i)
        if ok then base = size end
      end
      if (type(base) ~= "number" or base <= 0) and GetChatWindowInfo then
        local ok, _, size = pcall(GetChatWindowInfo, i)
        if ok then base = size end
      end
      if type(base) ~= "number" or base <= 0 then
        -- Last resort: the current size, unless it is the one we drew
        -- (scaling it again would shrink the text every time).
        local ok, _, size = pcall(cf.GetFont, cf)
        if ok and type(size) == "number" and cf.pssDrawn and math.abs(size - cf.pssDrawn) < 0.5 then
          base = cf.pssBase or 14
        else
          base = ok and size or 14
        end
      end
      cf.pssBase, cf.pssDrawn = base, self:ChatFontSize(base)
      local _, _, flags = cf:GetFont()
      pcall(cf.SetFont, cf, FONT, self:ChatFontSize(base), flags or "")
      if not chatFontFrames[cf] then
        chatFontFrames[cf] = true
        for _, m in ipairs({"SetFont", "SetFontObject"}) do
          if type(cf[m]) == "function" then pcall(PSS.HookSecure, cf, m, ChatFontAgain) end
        end
      end
    end
  end
  chatFontBusy = false
  if not self.chatFontEvents and CreateFrame then
    local f = CreateFrame("Frame")
    for _, e in ipairs({"UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "PLAYER_ENTERING_WORLD"}) do
      pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function()
      PSS:Soon("chatfonts", function() LY:ChatFonts() end, 0.5)
      if C_Timer and C_Timer.After then C_Timer.After(3, function() LY:ChatFonts() end) end
    end)
    self.chatFontEvents = f
  end
  if not chatFontHooked and hooksecurefunc and type(FCF_SetChatWindowFontSize) == "function" then
    chatFontHooked = true
    PSS.HookSecure("FCF_SetChatWindowFontSize", function()
      if C_Timer and C_Timer.After then C_Timer.After(0, function() LY:ChatFonts() end) else LY:ChatFonts() end
    end)
  end
end

---------------------------------------------------------------------------
-- Apply / reload prompt
---------------------------------------------------------------------------
local PARTS = {
  {"units", function()
    BuildUnits(); StartUnitEvents(); PlaceCastBar()
    if PSS.Auras then PSS.Auras:Apply() end
  end},
  {"bars", BuildBars},
  {"chat", function() BuildChat(); BuildChatHooks(); LY:PlaceMenus(); LY:UpdateInfo() end},
  {"minimap", BuildMinimap},
  {"fonts", ApplyFonts},
  {"plates", function() if PSS.Plates then PSS.Plates:Apply() end end},
  {"party", function() BuildParty() end},
  {"bags", function() LY:CombinedBags(true) end},
}

function LY:Apply()
  if InCombat() then self.pending = true; return end
  self.pending = false
  local S = PSS.Skin
  if S and S:Wanted() and not S.active then S:Refresh() end
  if S and S.UpdateColours then S.UpdateColours() end
  for _, p in ipairs(PARTS) do
    if self:Want(p[1]) and not self.applied[p[1]] then
      self.applied[p[1]] = true
      local ok, err = pcall(p[2])
      if not ok and PSS.Debug then PSS:Debug("layout " .. p[1] .. ": " .. tostring(err)) end
    end
  end
  if self.applied.bars then pcall(self.LayoutBars, self) end
  if self.applied.minimap then pcall(self.PlaceXP, self) end
  if self.applied.chat then pcall(self.PlaceChat, self); pcall(self.PlaceMenus, self) end
  if self.applied.units then
    PlaceCastBar()
    if PSS.Auras and PSS.Auras.on then pcall(PSS.Auras.Place, PSS.Auras); pcall(PSS.Auras.StyleAll, PSS.Auras) end
  end
  if self.applied.bars and self.barHolderFrame then self:Movable("bars", self.barHolderFrame, "slot_bars") end
  if self.applied.chat then
    if G("PetSkillScoutChatPanel") then self:Movable("chat", G("PetSkillScoutChatPanel"), "slot_chat") end
    if G("PetSkillScoutInfoBar") then self:Movable("info", G("PetSkillScoutInfoBar"), "slot_info") end
  end
  if self.applied.minimap then
    if G("PetSkillScoutMinimapHolder") then self:Movable("minimap", G("PetSkillScoutMinimapHolder"), "slot_minimap") end
    if self.bar then self:Movable("buttons", self.bar, "slot_buttons") end
  end
  if PSS.ShotTimer and PSS.ShotTimer:Enabled() then self:Movable("shot", PSS.ShotTimer:Build(), "slot_shot") end
  pcall(self.ApplyPositions, self)
  -- The combined bag option goes back to what it was when the part is off.
  if not self:Want("bags") then
    self:CombinedBags(false)
    self.applied.bags = nil -- no reload needed for this part
  end
  self:CheckReload()
end

---------------------------------------------------------------------------
-- One bag: the game's own combined bag (themed by the skin), switched on
-- while this part is on; the previous setting is restored when it is off.
---------------------------------------------------------------------------
local function GetCVarValue(name)
  if C_CVar and C_CVar.GetCVar then return Call(C_CVar.GetCVar, name) end
  if GetCVar then return Call(GetCVar, name) end
end
local function SetCVarValue(name, v)
  if C_CVar and C_CVar.SetCVar then return Call(C_CVar.SetCVar, name, v) end
  if SetCVar then return Call(SetCVar, name, v) end
end

function LY:CombinedBags(on)
  if not PetSkillScoutDB then return end
  local cur = GetCVarValue("combinedBags")
  if cur == nil then return false end -- this client has no combined bag
  if on then
    if PetSkillScoutDB.pssOldCombined == nil then PetSkillScoutDB.pssOldCombined = tostring(cur) end
    if tostring(cur) ~= "1" then SetCVarValue("combinedBags", "1") end
  elseif PetSkillScoutDB.pssOldCombined ~= nil then
    SetCVarValue("combinedBags", PetSkillScoutDB.pssOldCombined)
    PetSkillScoutDB.pssOldCombined = nil
  end
  return true
end

---------------------------------------------------------------------------
-- Move mode: every element of the layout can be dragged; positions are
-- saved per character. Out of combat only (some frames are secure).
---------------------------------------------------------------------------
LY.movables = {}
local movers = {}

function LY:Saved(key)
  local t = PetSkillScoutDB and PetSkillScoutDB.layoutPos
  return t and t[key]
end

function LY:Movable(key, frame, label)
  if type(frame) ~= "table" then return end
  local m = self.movables[key]
  if m and m.frame == frame then return end
  local pts = {}
  for i = 1, (frame.GetNumPoints and frame:GetNumPoints() or 0) do pts[i] = {frame:GetPoint(i)} end
  self.movables[key] = {key = key, frame = frame, label = label, default = pts}
  if self:Saved(key) and not InCombat() then self:ApplyPosition(key) end
end

function LY:ApplyPosition(key)
  local m = self.movables[key]
  local pos = self:Saved(key)
  if not (m and pos) or InCombat() then return end
  local f = m.frame
  local scale = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  if scale <= 0 then scale = 1 end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x / scale, pos.y / scale)
end

function LY:ApplyPositions()
  for key in pairs(self.movables) do self:ApplyPosition(key) end
end

function LY:ResetPosition(key)
  local m = self.movables[key]
  if not m or InCombat() then return end
  if PetSkillScoutDB and PetSkillScoutDB.layoutPos then PetSkillScoutDB.layoutPos[key] = nil end
  m.frame:ClearAllPoints()
  for _, p in ipairs(m.default) do pcall(m.frame.SetPoint, m.frame, unpack(p)) end
  if key == "buttons" then pcall(self.ArrangeButtonBar, self) end
end

local function MoverFor(m)
  local mv = movers[m.key]
  if not mv then
    mv = CreateFrame("Frame", nil, UIParent)
    mv:SetFrameStrata("DIALOG")
    mv:EnableMouse(true)
    mv:SetMovable(true)
    if mv.SetClampedToScreen then mv:SetClampedToScreen(true) end
    mv:RegisterForDrag("LeftButton")
    mv.fill = mv:CreateTexture(nil, "BACKGROUND")
    mv.fill:SetAllPoints(); mv.fill:SetTexture(FLAT)
    mv.label = Text(mv, 11, "CENTER")
    mv.label:SetPoint("CENTER")
    mv:SetScript("OnDragStart", function(self) if not InCombat() then self:StartMoving() end end)
    mv:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local x, y = self:GetCenter()
      if not (x and y) or not PetSkillScoutDB then return end
      local s = (self:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
      PetSkillScoutDB.layoutPos = PetSkillScoutDB.layoutPos or {}
      PetSkillScoutDB.layoutPos[m.key] = {x = x * s, y = y * s}
      LY:ApplyPosition(m.key)
    end)
    mv:SetScript("OnMouseUp", function(self, button)
      if button == "RightButton" then LY:ResetPosition(m.key); LY:Unlock(true) end
    end)
    movers[m.key] = mv
  end
  local f = m.frame
  local s = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
  mv:SetSize(math.max(40, (f:GetWidth() or 40) * s), math.max(18, (f:GetHeight() or 18) * s))
  mv:ClearAllPoints()
  local x, y = f:GetCenter()
  if x and y then mv:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s, y * s) end
  local acc = Col("accent")
  mv.fill:SetVertexColor(acc[1], acc[2], acc[3], 0.28)
  if PSS.Skin then
    local bd = PSS.Skin:Backdrop(mv, "button", {0, 0, 0, 0}, "OVERLAY")
    if bd then
      bd.bg:Hide()
      for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(acc[1], acc[2], acc[3], 1) end
    end
  end
  mv.label:SetText(L(m.label))
  return mv
end

function LY:Unlock(on)
  if on and InCombat() then PSS:Print(L("moveCombat")); return end
  self.unlocked = on and true or false
  for key, m in pairs(self.movables) do
    if on then MoverFor(m):Show() elseif movers[key] then movers[key]:Hide() end
  end
  if on and not self.moveBox then
    local f = Panel("PetSkillScoutMoveBox", UIParent, "window")
    f:SetSize(420, 74)
    f:SetPoint("TOP", UIParent, "TOP", 0, -90)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f.text = Text(f, 12, "CENTER")
    f.text:SetPoint("TOP", f, "TOP", 0, -12)
    f.text:SetWidth(396)
    local done = CreateFrame("Button", nil, f)
    done:SetSize(150, 24); done:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 10)
    done.t = Text(done, 11, "CENTER"); done.t:SetAllPoints()
    done:SetScript("OnClick", function() LY:Unlock(false) end)
    local reset = CreateFrame("Button", nil, f)
    reset:SetSize(150, 24); reset:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 10)
    reset.t = Text(reset, 11, "CENTER"); reset.t:SetAllPoints()
    reset:SetScript("OnClick", function()
      for key in pairs(LY.movables) do LY:ResetPosition(key) end
      LY:Unlock(true)
    end)
    f.done, f.reset = done, reset
    self.moveBox = f
  end
  if self.moveBox then
    local f = self.moveBox
    if on then
      f.text:SetText(L("moveHint"))
      f.done.t:SetText(L("moveDone")); f.reset.t:SetText(L("moveReset"))
      if PSS.Skin then
        PSS.Skin:Backdrop(f, "window"); PSS.Skin:Backdrop(f.done, "button"); PSS.Skin:Backdrop(f.reset, "button")
      end
      f:Show()
    else
      f:Hide()
    end
  end
end

local lockFrame = CreateFrame("Frame")
pcall(lockFrame.RegisterEvent, lockFrame, "PLAYER_REGEN_DISABLED")
lockFrame:SetScript("OnEvent", function() if LY.unlocked then LY:Unlock(false); PSS:Print(L("moveCombat")) end end)

-- A part that is on now but no longer wanted can only go away with /reload.
function LY:NeedsReload()
  for _, p in ipairs(PARTS) do
    if self.applied[p[1]] and not self:Want(p[1]) then return true end
  end
  return false
end

function LY:CheckReload()
  if not self:NeedsReload() then
    if self.reloadBox then self.reloadBox:Hide() end
    return
  end
  if not self.reloadBox then
    local f = Panel("PetSkillScoutReloadBox", UIParent, "window")
    f:SetSize(340, 86)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    f:SetFrameStrata("DIALOG")
    f.text = Text(f, 12, "CENTER")
    f.text:SetPoint("TOP", f, "TOP", 0, -14)
    f.text:SetWidth(310)
    f.text:SetText(L("skinReload"))
    local yes = CreateFrame("Button", nil, f)
    yes:SetSize(130, 24)
    yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 12)
    BD(yes, "button")
    yes.t = Text(yes, 11, "CENTER"); yes.t:SetAllPoints(); yes.t:SetText(L("skinReloadNow"))
    yes:SetScript("OnClick", function() if ReloadUI then ReloadUI() end end)
    local no = CreateFrame("Button", nil, f)
    no:SetSize(130, 24)
    no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 12)
    BD(no, "button")
    no.t = Text(no, 11, "CENTER"); no.t:SetAllPoints(); no.t:SetText(L("skinReloadLater"))
    no:SetScript("OnClick", function() f:Hide() end)
    self.reloadBox = f
    f.yes, f.no = yes, no
  end
  -- Drawn even when the skin itself is off (Classic theme picked).
  local S, f = PSS.Skin, self.reloadBox
  if S then
    if S.UpdateColours then S.UpdateColours() end
    S:Backdrop(f, "window"); S:Backdrop(f.yes, "button"); S:Backdrop(f.no, "button")
  end
  f:Show()
end

LY.frame = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_CHAT_WINDOWS"}) do
  pcall(LY.frame.RegisterEvent, LY.frame, e)
end
LY.frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if LY.pending then pcall(LY.Apply, LY) end
    if LY.pendingLayout then LY.pendingLayout = false; pcall(LY.LayoutBars, LY); PlaceCastBar(); pcall(LY.FitChatFrame, LY) end
  elseif event == "UPDATE_CHAT_WINDOWS" then
    if LY.applied.chat then pcall(LY.PlaceChat, LY) end
  else
    pcall(LY.Apply, LY)
  end
end)
