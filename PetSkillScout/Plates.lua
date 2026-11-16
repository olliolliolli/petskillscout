-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Nameplates in the interface theme (Settings > Interface > Nameplates).
-- Blizzard's own nameplates are restyled, not replaced: flat health bar,
-- thin theme border (accent colour on your target instead of the yellow
-- frame), flat level box, clean name text, flat cast bar. For hunters a
-- small tag under the name of tameable beasts shows the family (purple for
-- rare pets). Forbidden plates (restricted areas) are left alone; all state
-- is kept in local tables, nothing is written into Blizzard frames.
local PSS = PetSkillScout
PSS.Plates = {}
local P = PSS.Plates

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end
local function F(t, k) local v = type(t) == "table" and t[k]; return type(v) == "table" and v or nil end
local function Col(k)
  local S = PSS.Skin
  return S and S.colours and S.colours[k] or {0.3, 0.3, 0.3, 1}
end

local plateUnit = setmetatable({}, {__mode = "k"}) -- unit frame -> unit token
local tags = setmetatable({}, {__mode = "k"})      -- unit frame -> our tag fontstring
local bars = setmetatable({}, {__mode = "k"})      -- health bar -> unit frame

local function Forbidden(f)
  if not f or not f.IsForbidden then return false end
  local ok, r = pcall(f.IsForbidden, f)
  return not ok or r
end

local function FadeAll(frame)
  local S = PSS.Skin
  if type(frame) ~= "table" or not (S and frame.GetRegions) then return end
  for _, r in ipairs({frame:GetRegions()}) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then S.Fade(r) end
  end
end

local function Font(fs, size)
  if type(fs) == "table" and fs.SetFont then pcall(fs.SetFont, fs, FONT, size, "OUTLINE") end
end

local function EdgeColour(bd, c)
  if not (bd and c) then return end
  for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

local function UnitFrameOf(plate)
  return F(plate, "UnitFrame") or plate
end

-- Tameable tag for hunters: "Bear", purple when it is a rare pet.
function P:Tag(unit)
  local _, class = Call(UnitClass, "player")
  if Plain(class) ~= "HUNTER" then return nil end
  local guid = Plain(Call(UnitGUID, unit))
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  local rec = PSS.Atlas and PSS.Atlas:Get(tonumber(id))
  if not rec then return nil end
  local text = rec.family and PSS:NameFamily(rec.family) or PSS:L("rareCreature")
  return text, rec.isRare
end

function P:Style(plate, unit)
  local S = PSS.Skin
  if not (S and S.active and self.on) or Forbidden(plate) then return end
  local uf = UnitFrameOf(plate)
  if Forbidden(uf) then return end
  plateUnit[uf] = unit
  local hb = F(uf, "healthBar") or F(uf, "HealthBar")
  if hb then
    bars[hb] = uf
    pcall(hb.SetStatusBarTexture, hb, FLAT)
    FadeAll(F(hb, "border") or F(hb, "Border"))
    for _, k in ipairs({"bgTexture", "background", "Background"}) do
      local t = F(hb, k)
      if t then S.Fade(t) end
    end
    local bd = S:Backdrop(hb, "slot", {-1, 1, 1, -1}, "BACKGROUND")
    if bd then
      local sel = unit and Plain(Call(UnitIsUnit, unit, "target"))
      EdgeColour(bd, sel and Col("accent") or Col("edge"))
    end
  end
  for _, k in ipairs({"selectionHighlight", "aggroHighlight"}) do
    local t = F(uf, k)
    if t then S.Fade(t) end
  end
  -- Name and level.
  local name = F(uf, "name") or F(uf, "Name")
  if name then Font(name, 10) end
  local lf = F(uf, "LevelFrame")
  if lf then
    FadeAll(lf)
    local bd = S:Backdrop(lf, "slot", {1, -1, -1, 1}, "BACKGROUND")
    if bd then EdgeColour(bd, Col("edge")) end
    local lt = F(lf, "levelText") or F(lf, "LevelText")
    if lt then Font(lt, 10) end
  end
  -- Cast bar.
  local cb = F(uf, "castBar") or F(uf, "CastBar")
  if cb and not Forbidden(cb) then
    pcall(cb.SetStatusBarTexture, cb, FLAT)
    for _, k in ipairs({"Border", "border", "BorderShield", "Background", "background", "TextBorder"}) do
      local t = F(cb, k)
      if t then S.Fade(t) end
    end
    S:Backdrop(cb, "slot", {-1, 1, 1, -1}, "BACKGROUND")
    local icon = F(cb, "Icon")
    if icon and icon.SetTexCoord then pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92) end
    local txt = F(cb, "Text")
    if txt then Font(txt, 9) end
  end
  -- Tameable tag.
  local text, rare = self:Tag(unit)
  local tag = tags[uf]
  if text and not tag and hb then
    tag = hb:CreateFontString(nil, "OVERLAY")
    Font(tag, 9)
    tag:SetPoint("TOP", hb, "BOTTOM", 0, -3)
    tags[uf] = tag
  end
  if tag then
    if text then
      local acc = Col("accent")
      if rare then tag:SetTextColor(0.78, 0.61, 1) else tag:SetTextColor(acc[1], acc[2], acc[3]) end
      tag:SetText(text)
      tag:Show()
    else
      tag:Hide()
    end
  end
end

function P:UpdateTargets()
  local S = PSS.Skin
  if not (S and S.active and self.on) then return end
  for hb, uf in pairs(bars) do
    local unit = plateUnit[uf]
    local bd = S.BackdropOf and S:BackdropOf(hb)
    if bd and unit then
      local sel = Plain(Call(UnitIsUnit, unit, "target"))
      EdgeColour(bd, sel and Col("accent") or Col("edge"))
    end
  end
end

local function PlateFor(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
  local secure = issecure and Call(issecure) or false
  return Call(C_NamePlate.GetNamePlateForUnit, unit, secure)
end

function P:StyleAll()
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  for _, plate in ipairs(Call(C_NamePlate.GetNamePlates) or {}) do
    local uf = UnitFrameOf(plate)
    local unit = rawget(plate, "namePlateUnitToken")
    if type(unit) ~= "string" then unit = type(rawget(uf, "unit")) == "string" and uf.unit or plateUnit[uf] end
    pcall(P.Style, P, plate, unit)
  end
end

function P:Apply()
  self.on = true
  self:StyleAll()
end

P.frame = CreateFrame("Frame")
for _, e in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED"}) do
  pcall(P.frame.RegisterEvent, P.frame, e)
end
P.frame:SetScript("OnEvent", function(_, event, unit)
  if not P.on then return end
  if event == "NAME_PLATE_UNIT_ADDED" then
    local plate = PlateFor(unit)
    if plate then pcall(P.Style, P, plate, unit) end
    pcall(P.UpdateTargets, P)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = PlateFor(unit)
    local uf = plate and UnitFrameOf(plate)
    if uf then
      plateUnit[uf] = nil
      if tags[uf] then tags[uf]:Hide() end
    end
  else
    pcall(P.UpdateTargets, P)
  end
end)

-- Stacked nameplates: in a crowd the plates sit one above another in a column
-- instead of overlapping (the game's own setting, nameplateMotion 1). Set out
-- of combat only; option "Stack nameplates" (default on).
local stackEv = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do pcall(stackEv.RegisterEvent, stackEv, e) end
function PSS:ApplyPlateStacking()
  if not (SetCVar and GetCVar) or (InCombatLockdown and InCombatLockdown()) then return end
  local want = not (PetSkillScoutDB and PetSkillScoutDB.plateStack == false)
  local v = want and "1" or "0"
  if GetCVar("nameplateMotion") ~= v then pcall(SetCVar, "nameplateMotion", v) end
  -- A little room between stacked plates, so the bars do not touch.
  if want and GetCVar("nameplateOverlapV") and tonumber(GetCVar("nameplateOverlapV")) and tonumber(GetCVar("nameplateOverlapV")) > 1.0 then
    pcall(SetCVar, "nameplateOverlapV", "1.0")
  end
end
stackEv:SetScript("OnEvent", function() pcall(PSS.ApplyPlateStacking, PSS) end)

-- Clearer plates: health % on the bar, your debuffs with time left above it,
-- and a cast bar that says when a spell can be interrupted (bright orange bar,
-- gold edge, "KICK!"); grey when it cannot be. Display only.
local extra = setmetatable({}, {__mode = "k"})
local function Extra(uf, hb)
  local e = extra[uf]
  if e then return e end
  e = {}
  e.pct = hb:CreateFontString(nil, "OVERLAY")
  Font(e.pct, 9)
  e.pct:SetPoint("RIGHT", hb, "RIGHT", -2, 0)
  e.debuffs = {}
  for i = 1, 5 do
    local d = CreateFrame("Frame", nil, uf)
    d:SetSize(18, 18)
    d:SetPoint("BOTTOMLEFT", hb, "TOPLEFT", (i - 1) * 20, 14)
    local bg = d:CreateTexture(nil, "BACKGROUND"); bg:SetTexture(FLAT); bg:SetAllPoints(); bg:SetVertexColor(0, 0, 0, 1)
    d.icon = d:CreateTexture(nil, "ARTWORK"); d.icon:SetPoint("TOPLEFT", 1, -1); d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.time = d:CreateFontString(nil, "OVERLAY"); Font(d.time, 9); d.time:SetPoint("BOTTOM", d, "BOTTOM", 0, -1)
    d.count = d:CreateFontString(nil, "OVERLAY"); Font(d.count, 8); d.count:SetPoint("TOPRIGHT", d, "TOPRIGHT", 1, 1)
    d:Hide()
    e.debuffs[i] = d
  end
  extra[uf] = e
  return e
end

function P:UpdateHealth(uf, unit)
  local hb = F(uf, "healthBar") or F(uf, "HealthBar")
  if not hb then return end
  local e = Extra(uf, hb)
  local hp, max = Plain(Call(UnitHealth, unit)), Plain(Call(UnitHealthMax, unit))
  if type(hp) == "number" and type(max) == "number" and max > 0 then
    e.pct:SetText(string.format("%d%%", math.floor(hp / max * 100 + 0.5)))
  else
    e.pct:SetText("")
  end
end

function P:UpdateDebuffs(uf, unit)
  local hb = F(uf, "healthBar") or F(uf, "HealthBar")
  if not hb then return end
  local e = Extra(uf, hb)
  local shown = 0
  local now = GetTime and GetTime() or 0
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL|PLAYER")
      if not ok or type(a) ~= "table" then break end
      local icon, exp, n = Plain(a.icon), Plain(a.expirationTime), Plain(a.applications)
      if icon and shown < #e.debuffs then
        shown = shown + 1
        local d = e.debuffs[shown]
        d.icon:SetTexture(icon)
        local left = type(exp) == "number" and exp > 0 and exp - now or nil
        d.time:SetText(left and (left >= 60 and string.format("%dm", math.floor(left / 60)) or string.format("%d", math.floor(left + 0.5))) or "")
        d.count:SetText(type(n) == "number" and n > 1 and tostring(n) or "")
        d:Show()
      end
    end
  end
  for i = shown + 1, #e.debuffs do e.debuffs[i]:Hide() end
end

function P:UpdateCast(uf, unit)
  local cb = F(uf, "castBar") or F(uf, "CastBar")
  if not cb or Forbidden(cb) then return end
  local S = PSS.Skin
  local name, _, _, _, _, _, _, notInt = Call(UnitCastingInfo, unit)
  if not Plain(name) then name, _, _, _, _, _, notInt = Call(UnitChannelInfo, unit) end
  local bd = S and S.BackdropOf and S:BackdropOf(cb)
  if not cb.pssKick then
    cb.pssKick = cb:CreateFontString(nil, "OVERLAY")
    Font(cb.pssKick, 10)
    cb.pssKick:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end
  if Plain(name) then
    if Plain(notInt) == true then
      pcall(cb.SetStatusBarColor, cb, 0.55, 0.55, 0.55)
      if bd then EdgeColour(bd, Col("edge")) end
      cb.pssKick:SetText("")
    else
      pcall(cb.SetStatusBarColor, cb, 1, 0.55, 0.15)
      if bd then EdgeColour(bd, {1, 0.85, 0.2, 1}) end
      cb.pssKick:SetTextColor(1, 0.85, 0.2)
      cb.pssKick:SetText(PSS:L("plateKick"))
    end
  else
    cb.pssKick:SetText("")
  end
end

local function UF(unit)
  local plate = PlateFor(unit)
  local uf = plate and UnitFrameOf(plate)
  if uf and not Forbidden(uf) then return uf end
end

local liveEv = CreateFrame("Frame")
for _, e in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "NAME_PLATE_UNIT_ADDED"}) do
  pcall(liveEv.RegisterEvent, liveEv, e)
end
liveEv:SetScript("OnEvent", function(_, event, unit)
  if not (P.on and type(unit) == "string" and unit:find("^nameplate")) then return end
  if PetSkillScoutDB and PetSkillScoutDB.plateExtras == false then return end
  local uf = UF(unit)
  if not uf then return end
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then pcall(P.UpdateHealth, P, uf, unit)
  elseif event == "UNIT_AURA" then pcall(P.UpdateDebuffs, P, uf, unit)
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    pcall(P.UpdateHealth, P, uf, unit); pcall(P.UpdateDebuffs, P, uf, unit); pcall(P.UpdateCast, P, uf, unit)
  else pcall(P.UpdateCast, P, uf, unit) end
end)
-- Debuff timers tick down once a second.
local tickF = CreateFrame("Frame")
tickF.pssKey = "Plates debuffs"
tickF:SetScript("OnUpdate", function()
  if not P.on or (PetSkillScoutDB and PetSkillScoutDB.plateExtras == false) then return end
  for uf, unit in pairs(plateUnit) do
    if extra[uf] and type(unit) == "string" then pcall(P.UpdateDebuffs, P, uf, unit) end
  end
end)
PSS:Every(tickF, 1)
