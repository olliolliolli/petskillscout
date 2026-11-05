-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Auto Shot timer for hunters. A bar runs from one Auto Shot to the next;
-- the last 0.5 s (the aiming part of Auto Shot) is marked: moving there
-- delays the shot, so the bar turns red and says "Stand still" when you move
-- in that window. Display only; nothing is cast or moved for you.
local PSS = PetSkillScout
PSS.ShotTimer = {}
local ST = PSS.ShotTimer

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local AUTO_SHOT = 75
ST.AIM = 0.5

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end
local function L(k) return PSS:L(k) end
local function DB() return PetSkillScoutDB or {} end
local function Now() return GetTime and GetTime() or 0 end

function ST:Enabled()
  local _, class = Call(UnitClass, "player")
  return Plain(class) == "HUNTER" and DB().shotTimer ~= false
end

-- Ranged attack speed; the last good value is kept for secret values.
local lastSpeed = 2.8
function ST:Speed()
  local s = Plain(Call(UnitRangedDamage, "player"))
  if type(s) == "number" and s > 0.5 and s < 6 then lastSpeed = s end
  return lastSpeed
end

local function AutoShotName()
  local name = C_Spell and C_Spell.GetSpellName and Call(C_Spell.GetSpellName, AUTO_SHOT)
  if not name and GetSpellInfo then name = Call(GetSpellInfo, AUTO_SHOT) end
  return Plain(name)
end

local function Col(k)
  local S = PSS.Skin
  return S and S.colours and S.colours[k]
end

function ST:Build()
  if self.bar then return self.bar end
  local f = CreateFrame("Frame", "PetSkillScoutShotTimer", UIParent)
  f:SetSize(200, 12)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
  f:SetFrameStrata("MEDIUM")
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(); f.bg:SetTexture(FLAT); f.bg:SetVertexColor(0.05, 0.06, 0.08, 0.85)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("TOPLEFT"); f.fill:SetPoint("BOTTOMLEFT"); f.fill:SetTexture(FLAT)
  -- The aiming window at the right end.
  f.aim = f:CreateTexture(nil, "BORDER")
  f.aim:SetPoint("TOPRIGHT"); f.aim:SetPoint("BOTTOMRIGHT"); f.aim:SetTexture(FLAT)
  f.aim:SetVertexColor(1, 1, 1, 0.12)
  f.edge = {}
  for i = 1, 4 do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(FLAT)
    f.edge[i] = t
  end
  f.edge[1]:SetPoint("TOPLEFT", -1, 1); f.edge[1]:SetPoint("TOPRIGHT", 1, 1); f.edge[1]:SetHeight(1)
  f.edge[2]:SetPoint("BOTTOMLEFT", -1, -1); f.edge[2]:SetPoint("BOTTOMRIGHT", 1, -1); f.edge[2]:SetHeight(1)
  f.edge[3]:SetPoint("TOPLEFT", -1, 1); f.edge[3]:SetPoint("BOTTOMLEFT", -1, -1); f.edge[3]:SetWidth(1)
  f.edge[4]:SetPoint("TOPRIGHT", 1, 1); f.edge[4]:SetPoint("BOTTOMRIGHT", 1, -1); f.edge[4]:SetWidth(1)
  f.text = f:CreateFontString(nil, "OVERLAY")
  pcall(f.text.SetFont, f.text, FONT, 10, "OUTLINE")
  f.text:SetPoint("BOTTOM", f, "TOP", 0, 2)
  f.time = f:CreateFontString(nil, "OVERLAY")
  pcall(f.time.SetFont, f.time, FONT, 9, "OUTLINE")
  f.time:SetPoint("RIGHT", f, "LEFT", -4, 0)
  f:Hide()
  self.bar = f
  f:SetScript("OnUpdate", function(_, e) ST:OnUpdate(e) end)
  f:SetScript("OnSizeChanged", function(s) s.pssW, s.pssFill, s.pssAim = nil, nil, nil end)
  return f
end

function ST:Colours()
  local f = self.bar
  if not f then return end
  f.pssState, f.pssW = nil, nil
  local e = Col("edge") or {0.3, 0.3, 0.35}
  for _, t in ipairs(f.edge) do t:SetVertexColor(e[1], e[2], e[3], 1) end
end

-- State: shooting (Auto Shot on), last shot time.
ST.shooting, ST.last = false, nil

function ST:Shot()
  self.last = Now()
  self.speed = self:Speed()
  self:Show()
end

function ST:Show()
  if not self:Enabled() then return end
  local f = self:Build()
  self:Colours()
  f:Show()
end

function ST:OnUpdate()
  local f = self.bar
  if not f then return end
  if not self.last then
    if not self.shooting then f:Hide() end
    return
  end
  local speed = self.speed or self:Speed()
  local elapsed = Now() - self.last
  -- After the cycle: hide when Auto Shot is off, otherwise wait for the shot.
  if elapsed > speed + 0.4 and not self.shooting then
    f:Hide(); self.last = nil
    return
  end
  local p = math.min(1, elapsed / speed)
  local w = f.pssW or f:GetWidth() or 200
  f.pssW = w
  -- The bar moves every frame; text and colours only change when they differ.
  local fw = math.max(1, math.floor(w * p + 0.5))
  if fw ~= f.pssFill then f.pssFill = fw; f.fill:SetWidth(fw) end
  local aw = w * math.min(1, self.AIM / speed)
  if aw ~= f.pssAim then f.pssAim = aw; f.aim:SetWidth(aw) end
  local remain = math.max(0, speed - elapsed)
  local tenths = math.floor(remain * 10 + 0.5)
  if tenths ~= f.pssTenths then f.pssTenths = tenths; f.time:SetText(string.format("%.1f", tenths / 10)) end
  local aiming = remain <= self.AIM and self.shooting
  local state
  if aiming then
    local moving = (Plain(Call(GetUnitSpeed, "player")) or 0) > 0
    state = moving and "move" or "aim"
  else
    state = self.shooting and "shoot" or "off"
  end
  if state == f.pssState then return end
  f.pssState = state
  if state == "move" then
    f.fill:SetVertexColor(1, 0.3, 0.3, 1)
    f.text:SetText("|cffff5555" .. L("shotStand") .. "|r")
  elseif state == "aim" then
    f.fill:SetVertexColor(1, 0.85, 0.3, 1)
    f.text:SetText(L("shotAim"))
  else
    local acc = Col("accent") or {0.85, 0.7, 0.43}
    f.fill:SetVertexColor(acc[1], acc[2], acc[3], 1)
    f.text:SetText(state == "shoot" and "" or L("shotOff"))
  end
end

ST.frame = CreateFrame("Frame")
for _, e in ipairs({"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_ENTERING_WORLD"}) do
  pcall(ST.frame.RegisterEvent, ST.frame, e)
end
ST.frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "START_AUTOREPEAT_SPELL" then
    ST.shooting = true
    ST:Show()
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    ST.shooting = false
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit ~= "player" then return end
    local id = Plain(spellID)
    if id == AUTO_SHOT then ST:Shot(); return end
    -- Some clients report a different ID: compare names.
    if id and not ST.autoName then ST.autoName = AutoShotName() end
    if id and ST.autoName then
      local n = C_Spell and C_Spell.GetSpellName and Call(C_Spell.GetSpellName, id)
      if not n and GetSpellInfo then n = Call(GetSpellInfo, id) end
      if Plain(n) == ST.autoName then ST:Shot() end
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if ST:Enabled() then ST:Build(); ST:Colours() end
  end
end)
