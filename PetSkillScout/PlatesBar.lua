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
local W, H = 128, 14

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
  -- Same layout as the theme's unit frames: name inside on the left, health
  -- on the right, the level in its own small square box on the left.
  f.pct = f.bar:CreateFontString(nil, "OVERLAY"); f.pct:SetFont(FONT, 9, "OUTLINE"); f.pct:SetPoint("RIGHT", -3, 0)
  f.name = f.bar:CreateFontString(nil, "OVERLAY"); f.name:SetFont(FONT, 9, "OUTLINE")
  f.name:SetPoint("LEFT", 3, 0); f.name:SetPoint("RIGHT", f.pct, "LEFT", -4, 0)
  f.name:SetJustifyH("LEFT"); f.name:SetWordWrap(false)
  f.box = CreateFrame("Frame", nil, f); f.box:SetSize(H + 4, H)
  f.box:SetPoint("RIGHT", f, "LEFT", -3, 0)
  f.box.edge = f.box:CreateTexture(nil, "BACKGROUND", nil, -2); f.box.edge:SetTexture(FLAT)
  f.box.edge:SetPoint("TOPLEFT", -1, 1); f.box.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  f.box.bg = f.box:CreateTexture(nil, "BACKGROUND", nil, -1); f.box.bg:SetTexture(FLAT); f.box.bg:SetAllPoints()
  f.box.bg:SetVertexColor(0.06, 0.07, 0.06, 0.9)
  f.lvl = f.box:CreateFontString(nil, "OVERLAY"); f.lvl:SetFont(FONT, 9, "OUTLINE"); f.lvl:SetPoint("CENTER", 0, 0)
  -- Sharp gold points for elite / rare mobs: a diamond at each end and one
  -- on top, each with a dark core, like the spikes of an elite frame.
  f.spikes = {}
  local function Spike(size)
    local o = f:CreateTexture(nil, "OVERLAY", nil, 6); o:SetTexture(FLAT); o:SetSize(size, size); o:SetRotation(math.pi / 4)
    local i = f:CreateTexture(nil, "OVERLAY", nil, 7); i:SetTexture(FLAT); i:SetSize(size - 4, size - 4); i:SetRotation(math.pi / 4)
    i:SetPoint("CENTER", o, "CENTER", 0, 0)
    f.spikes[#f.spikes + 1] = {o = o, i = i}
    return o
  end
  Spike(11):SetPoint("CENTER", f, "RIGHT", 4, 0)
  Spike(11):SetPoint("CENTER", f.box, "LEFT", -4, 0)
  Spike(9):SetPoint("CENTER", f, "TOP", 0, 2)
  Spike(9):SetPoint("CENTER", f, "BOTTOM", 0, -2)
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
  -- Objects (furniture, fishing pools, chests...) have plates too, but no
  -- health and no level: the game hides both for them (NamePlateHealthBar
  -- IsGameObject, NameplateLevelFrameMixin:ShouldDisplay). Ours too.
  local obj = unit and UnitIsGameObject and Call(UnitIsGameObject, unit)
  local isObj = false
  pcall(function() isObj = obj and true or false end)
  if isObj then f:Hide(); return end
  f:ClearAllPoints()
  f:SetPoint("CENTER", hb, "CENTER", 0, 0)
  if unit then unitOf[unit] = uf end
  -- The game's own look: bar art, target glow, level badge, name.
  for _, k in ipairs({"barTexture", "background", "bgTexture", "border", "Border"}) do Hide(hb[k]) end
  Hide(hb)
  -- Forever keeps the game's health bar AND its level badge (the yellow ring)
  -- in one container: hidden as a whole, our bar is a separate frame.
  Hide(uf.HealthBarsContainer)
  -- Forever's own level badge (the yellow ring): PlayerLevelDiffFrame.
  Hide(uf.PlayerLevelDiffFrame)
  for _, k in ipairs({"selectionHighlight", "aggroHighlight", "SelectionBorder", "LevelFrame", "levelFrame"}) do Hide(uf[k]) end
  local gn = uf.name or uf.Name
  Hide(gn)
  -- Colour of the game's bar (reaction / tapped), passed on as it is.
  local r, g, b = Call(hb.GetStatusBarColor, hb)
  if r then pcall(f.bar.SetStatusBarColor, f.bar, r, g, b) end
  if gn and gn.GetText then pcall(f.name.SetText, f.name, gn:GetText()) end
  -- Level from the unit itself (the game's badge text was not the mob's
  -- level here: a "60" showed); "??" for skull mobs.
  local lv = unit and Call(UnitLevel, unit)
  local okL = pcall(function()
    if lv == -1 then f.lvl:SetText("??") else f.lvl:SetFormattedText("%d", lv) end
  end)
  if not okL then f.lvl:SetText("") end
  -- The game's own level badge (the yellow "38" box): any child that holds a
  -- level text is hidden, whatever this client calls it.
  -- Found by its content: a text that is just the level number (or "??"),
  -- anywhere under the plate except our own frame; its holder is hidden.
  local function hideLevel(fr, depth)
    if depth > 4 or fr == f then return end
    if rawget(fr, "levelText") or rawget(fr, "LevelText") or rawget(fr, "Level") then Hide(fr) end
    for _, r in ipairs({fr:GetRegions()}) do
      if r.GetObjectType and r:GetObjectType() == "FontString" then
        local isLvl = false
        pcall(function() local t = r:GetText(); isLvl = type(t) == "string" and (t:match("^%d+$") or t == "??") and true or false end)
        if isLvl then
          Hide(r)
          if fr ~= uf and fr ~= hb then Hide(fr) end
        end
      end
    end
    for _, c in ipairs({fr:GetChildren()}) do hideLevel(c, depth + 1) end
  end
  hideLevel(uf, 0)
  -- (No search by position: nameplate parts cannot be measured on this
  -- client, "Can't measure restricted regions".)
  -- Our level coloured like the game's: by how hard the mob is for you.
  f.lvlColoured = false
  -- The standard level colours, worked out here: red 5+ levels above you,
  -- orange 3-4, yellow within 2, green below that, grey when it gives no XP
  -- (the game's grey level for your level). Skull: red.
  pcall(function()
    local me = UnitLevel("player")
    local diff = lv - me
    local r, g, b
    if lv == -1 or diff >= 5 then r, g, b = 1, 0.1, 0.1
    elseif diff >= 3 then r, g, b = 1, 0.5, 0.25
    elseif diff >= -2 then r, g, b = 1, 0.82, 0
    else
      local grey = (GetQuestGreyLevel and GetQuestGreyLevel()) or (me <= 5 and 0 or me <= 39 and me - math.floor(me / 10) - 5 or me <= 59 and me - math.floor(me / 5) - 1 or me - 9)
      if lv <= grey then r, g, b = 0.5, 0.5, 0.5 else r, g, b = 0.25, 0.75, 0.25 end
    end
    f.lvl:SetTextColor(r, g, b)
    f.lvlColoured = true
  end)
  -- The game already colours its own (hidden) level badge by difficulty: the
  -- same colour is taken over as it is (works when the level is secret).
  local diff = uf.PlayerLevelDiffFrame and uf.PlayerLevelDiffFrame.playerLevelDiffText
  -- The difficulty colour sits either on the badge's ring (a texture tinted
  -- by the game) or on its number: the first one that is not plain white.
  local pld = uf.PlayerLevelDiffFrame
  local function useColour(r, g, b)
    local white = false
    pcall(function() white = r > 0.95 and g > 0.95 and b > 0.95 end)
    if white then return false end
    return pcall(f.lvl.SetTextColor, f.lvl, r, g, b)
  end
  if not f.lvlColoured and pld and pld.GetRegions then
    for _, r in ipairs({pld:GetRegions()}) do
      if not f.lvlColoured and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetVertexColor then
        local okV, cr, cg, cb = pcall(r.GetVertexColor, r)
        if okV and cr and useColour(cr, cg, cb) then f.lvlColoured = true end
      end
    end
  end
  if not f.lvlColoured and diff and diff.GetTextColor then
    local okD, cr, cg, cb = pcall(diff.GetTextColor, diff)
    if okD and cr and useColour(cr, cg, cb) then f.lvlColoured = true end
  end
  local okC = f.lvlColoured or pcall(function()
    if lv == -1 then f.lvl:SetTextColor(1, 0.1, 0.1); f.lvlColoured = true; return end
    local dc = GetCreatureDifficultyColor and GetCreatureDifficultyColor(lv) or (GetQuestDifficultyColor and GetQuestDifficultyColor(lv))
    if dc and dc.r then f.lvl:SetTextColor(dc.r, dc.g, dc.b); f.lvlColoured = true end
  end)
  if not okC then f.lvlColoured = false end
  -- Edges in the theme's edge colour (as every theme frame); your target in
  -- the accent colour and a little thicker.
  local sel = unit and Call(UnitIsUnit, unit, "target")
  local isSel = false
  pcall(function() isSel = sel and true or false end)
  local c = isSel and Col("accent") or Col("edge")
  local w = isSel and 2 or 1
  -- Elite, rare and boss mobs: a gold frame (thicker when it is your target).
  local cls = unit and Call(UnitClassification, unit)
  local special = false
  pcall(function() special = cls == "elite" or cls == "rareelite" or cls == "rare" or cls == "worldboss" end)
  -- Dungeon and raid bosses (BossDB, from ATT): red-orange, always thick.
  local boss = unit and PSS.IsBoss and PSS:IsBoss(unit)
  if boss then special = true end
  if special then
    c = boss and {1, 0.35, 0.2, 1} or {1, 0.8, 0.25, 1}
    w = (isSel or boss) and 3 or 2
  end
  -- Gold points for every elite, rare and boss mob.
  local rareOnly = false
  pcall(function() rareOnly = cls == "rare" end)
  for _, sp in ipairs(f.spikes or {}) do
    sp.o:SetShown(special and true or false); sp.i:SetShown(special and true or false)
    if special then
      sp.o:SetVertexColor(1, 0.8, 0.25, 1)
      sp.i:SetVertexColor(0.08, 0.06, 0.03, 1)
    end
  end
  f.edge:ClearAllPoints(); f.edge:SetPoint("TOPLEFT", -w, w); f.edge:SetPoint("BOTTOMRIGHT", w, -w)
  -- The level box: same height and same edge as the bar.
  f.box:SetSize(H + 6, H)
  f.box:ClearAllPoints(); f.box:SetPoint("RIGHT", f, "LEFT", -(w * 2 + 2), 0)
  f.box.edge:ClearAllPoints(); f.box.edge:SetPoint("TOPLEFT", -w, w); f.box.edge:SetPoint("BOTTOMRIGHT", w, -w)
  f.edge:SetVertexColor(c[1], c[2], c[3], 1)
  f.box.edge:SetVertexColor(c[1], c[2], c[3], 1)
  local bgc = Col("slot")
  f.bg:SetVertexColor(bgc[1], bgc[2], bgc[3], 0.85); f.box.bg:SetVertexColor(bgc[1], bgc[2], bgc[3], 0.85)
  if not f.lvlColoured then f.lvl:SetTextColor(c[1], c[2], c[3]) end
  f:Show()
  self:SquareHealth(uf, unit)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UNIT_HEALTH",
    "UNIT_MAXHEALTH", "UNIT_FACTION", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED"}) do pcall(ev.RegisterEvent, ev, e) end
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
