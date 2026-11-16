-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Square theme nameplates. The game's round health bar, its yellow target
-- glow and the level badge are made invisible and our own flat bar is drawn
-- in their place: square, 1 px edge, the theme's accent edge on your target,
-- health in % inside. Values go straight from the game to the bar and text
-- (they may be secret on this client; widgets accept them, Lua does not read
-- them). Display only.
local PSS = PetSkillScout
local P = PSS.Plates
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local W, H = 120, 10

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = {pcall(fn, ...)}
  if r[1] then return unpack(r, 2, 10) end
end
local function Col(k)
  local S = PSS.Skin
  local c = S and S.Colour and S:Colour(k)
  return c or {0.86, 0.7, 0.35, 1}
end
local function On()
  return P.on and PSS.Skin and PSS.Skin.active and not (PetSkillScoutDB and PetSkillScoutDB.plateExtras == false)
end

local ours = setmetatable({}, {__mode = "k"}) -- unit frame -> our bar frame
local unitOf = {}                              -- unit token -> unit frame

local function Hide(region)
  if type(region) ~= "table" or not region.SetAlpha then return end
  pcall(region.SetAlpha, region, 0)
  if not region.pssPlateHidden and hooksecurefunc then
    region.pssPlateHidden = true
    pcall(hooksecurefunc, region, "SetAlpha", function(r, a) if a ~= 0 and On() then r:SetAlpha(0) end end)
  end
end

local function Build(uf)
  local f = ours[uf]
  if f then return f end
  f = CreateFrame("Frame", nil, uf)
  f:SetSize(W, H)
  f:SetFrameLevel((uf:GetFrameLevel() or 1) + 5)
  f.edge = f:CreateTexture(nil, "BACKGROUND", nil, -2); f.edge:SetTexture(FLAT)
  f.edge:SetPoint("TOPLEFT", -1, 1); f.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -1); f.bg:SetTexture(FLAT); f.bg:SetAllPoints()
  f.bg:SetVertexColor(0.06, 0.07, 0.06, 0.9)
  f.bar = CreateFrame("StatusBar", nil, f); f.bar:SetAllPoints(); f.bar:SetStatusBarTexture(FLAT)
  f.pct = f.bar:CreateFontString(nil, "OVERLAY"); f.pct:SetFont(FONT, 9, "OUTLINE"); f.pct:SetPoint("RIGHT", -2, 0)
  f.name = f:CreateFontString(nil, "OVERLAY"); f.name:SetFont(FONT, 10, "OUTLINE")
  f.name:SetPoint("BOTTOM", f, "TOP", 0, 3)
  f.lvl = f:CreateFontString(nil, "OVERLAY"); f.lvl:SetFont(FONT, 9, "OUTLINE")
  f.lvl:SetPoint("LEFT", f, "RIGHT", 4, 0)
  ours[uf] = f
  return f
end

function P:SquareHealth(uf, unit)
  local f = ours[uf]
  if not f or not unit then return end
  local hp, max = Call(UnitHealth, unit), Call(UnitHealthMax, unit)
  if max then pcall(f.bar.SetMinMaxValues, f.bar, 0, max) end
  if hp then pcall(f.bar.SetValue, f.bar, hp) end
  -- Percent text: a secret-safe game helper when there is one.
  if UnitHealthPercent then
    local ok = pcall(function() f.pct:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)) end)
    if not ok then f.pct:SetText("") end
  else
    local ok = pcall(function() f.pct:SetFormattedText("%d%%", math.floor(hp / max * 100 + 0.5)) end)
    if not ok then f.pct:SetText("") end
  end
end

function P:SquareStyle(uf, unit)
  if not On() then return end
  local hb = uf.healthBar or uf.HealthBar
  if not hb then return end
  local f = Build(uf)
  f:ClearAllPoints()
  f:SetPoint("CENTER", hb, "CENTER", 0, 0)
  if unit then unitOf[unit] = uf end
  -- The game's own look: bar art, target glow, level badge, name.
  for _, k in ipairs({"barTexture", "background", "bgTexture", "border", "Border"}) do Hide(hb[k]) end
  Hide(hb)
  for _, k in ipairs({"selectionHighlight", "aggroHighlight", "SelectionBorder", "LevelFrame", "levelFrame"}) do Hide(uf[k]) end
  local gn = uf.name or uf.Name
  Hide(gn)
  -- Colour of the game's bar (reaction / tapped), passed on as it is.
  local r, g, b = Call(hb.GetStatusBarColor, hb)
  if r then pcall(f.bar.SetStatusBarColor, f.bar, r, g, b) end
  if gn and gn.GetText then pcall(f.name.SetText, f.name, gn:GetText()) end
  local lt = (uf.LevelFrame or uf.levelFrame) and ((uf.LevelFrame or uf.levelFrame).levelText or (uf.LevelFrame or uf.levelFrame).LevelText)
  if lt and lt.GetText then pcall(f.lvl.SetText, f.lvl, lt:GetText()) end
  local sel = unit and Call(UnitIsUnit, unit, "target")
  local c = sel and Col("accent") or Col("edge")
  local ok = pcall(function() if sel then f.edge:SetVertexColor(c[1], c[2], c[3], 1) else f.edge:SetVertexColor(0, 0, 0, 1) end end)
  if not ok then f.edge:SetVertexColor(0, 0, 0, 1) end
  f:Show()
  self:SquareHealth(uf, unit)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH",
    "UNIT_MAXHEALTH", "UNIT_FACTION", "UNIT_LEVEL"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then
    for u, uf in pairs(unitOf) do pcall(P.SquareStyle, P, uf, u) end
    return
  end
  if type(unit) ~= "string" or not unit:find("^nameplate") then return end
  if event == "NAME_PLATE_UNIT_REMOVED" then
    local uf = unitOf[unit]
    if uf and ours[uf] then ours[uf]:Hide() end
    unitOf[unit] = nil
    return
  end
  if not On() then return end
  local plate = C_NamePlate and Call(C_NamePlate.GetNamePlateForUnit, unit, issecure and issecure() or false)
  local uf = plate and (plate.UnitFrame or plate)
  if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then pcall(P.SquareHealth, P, uf, unit)
  else pcall(P.SquareStyle, P, uf, unit) end
end)
