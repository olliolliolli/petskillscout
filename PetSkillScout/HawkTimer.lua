-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Summon Hawk timer (WoW Forever, Beast Mastery). Each hawk lives 18 s and
-- you can have two. Two small bars above the action bars show how long each
-- hawk has left, so you do not recast while both are up; the bars and the
-- Summon Hawk button glow when it is time to recast (fewer than two hawks,
-- or one runs out within the refresh window). Display only: nothing is cast.
local PSS = PetSkillScout
PSS.HawkTimer = {}
local H = PSS.HawkTimer

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
H.LIFE, H.MAX = 18, 2

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end
local function DB() return PetSkillScoutDB or {} end
local function Now() return GetTime and GetTime() or 0 end
local function L(k) return PSS:L(k) end

function H:Enabled()
  local _, class = Call(UnitClass, "player")
  return Plain(class) == "HUNTER" and DB().hawkTimer ~= false
end
function H:Refresh() return tonumber(DB().hawkRefresh) or 4 end

-- The spell: found by name (English client name, or the name the game gives
-- for the ID once seen), remembered by ID.
local function IsHawk(spellID)
  if not spellID then return false end
  if DB().hawkSpell == spellID then return true end
  local name
  if C_Spell and C_Spell.GetSpellName then name = Plain(Call(C_Spell.GetSpellName, spellID))
  elseif GetSpellInfo then name = Plain(Call(GetSpellInfo, spellID)) end
  if type(name) ~= "string" then return false end
  local n = name:lower()
  if n:find("summon hawk", 1, true) or (n:find("hawk", 1, true) and n:find("summon", 1, true)) or n:find("яструб", 1, true) then
    if PetSkillScoutDB then PetSkillScoutDB.hawkSpell = spellID end
    return true
  end
  return false
end

H.hawks = {} -- expiry times, oldest first

function H:Cast()
  local now = Now()
  local list = {}
  for _, t in ipairs(self.hawks) do if t > now then list[#list + 1] = t end end
  if #list >= self.MAX then table.remove(list, 1) end
  list[#list + 1] = now + self.LIFE
  self.hawks = list
  self:Update()
end

-- Two hawk squares in the look of the Cooldown Manager icons ---------------
-- Summon Hawk's icon, the seconds left in the middle, a dark swipe that runs
-- down with the hawk, a thin theme edge; the edge glows in the accent colour
-- when it is time to recast. Next to the Cooldown Manager when it is shown.
local frame, bars, glows = nil, {}, {}
local function Accent()
  local S = PSS.Skin
  local c = S and S.Colour and S:Colour("accent")
  return c or {0.86, 0.7, 0.35}
end
local SIZE, GAP = 38, 4

local function Edge(f, r, g, b, a, w)
  for _, e in ipairs(f.edges) do e:SetVertexColor(r, g, b, a) end
  f.edges[1]:SetHeight(w); f.edges[2]:SetHeight(w); f.edges[3]:SetWidth(w); f.edges[4]:SetWidth(w)
end

local function Square(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(SIZE, SIZE)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(FLAT); bg:SetAllPoints(); bg:SetVertexColor(0.05, 0.06, 0.05, 0.9)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 1, -1); f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.shade = f:CreateTexture(nil, "ARTWORK", nil, 2)
  f.shade:SetTexture(FLAT); f.shade:SetVertexColor(0, 0, 0, 0.65)
  f.shade:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMLEFT"); f.shade:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT")
  f.edges = {}
  for i = 1, 4 do f.edges[i] = f:CreateTexture(nil, "OVERLAY"); f.edges[i]:SetTexture(FLAT) end
  f.edges[1]:SetPoint("TOPLEFT"); f.edges[1]:SetPoint("TOPRIGHT")
  f.edges[2]:SetPoint("BOTTOMLEFT"); f.edges[2]:SetPoint("BOTTOMRIGHT")
  f.edges[3]:SetPoint("TOPLEFT"); f.edges[3]:SetPoint("BOTTOMLEFT")
  f.edges[4]:SetPoint("TOPRIGHT"); f.edges[4]:SetPoint("BOTTOMRIGHT")
  f.text = f:CreateFontString(nil, "OVERLAY", nil, 3)
  f.text:SetFont(FONT, 15, "OUTLINE"); f.text:SetPoint("CENTER", 0, 0)
  f.num = f:CreateFontString(nil, "OVERLAY", nil, 3)
  f.num:SetFont(FONT, 9, "OUTLINE"); f.num:SetPoint("BOTTOMRIGHT", -2, 2); f.num:SetTextColor(0.8, 0.8, 0.75)
  return f
end

local function Place()
  if not frame then return end
  local pos = DB().hawkPos
  frame:ClearAllPoints()
  local cdm = _G.EssentialCooldownViewer
  if pos and pos.x then
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  elseif cdm and cdm:IsShown() and (cdm:GetEffectiveAlpha() or 0) > 0.05 then
    frame:SetPoint("RIGHT", cdm, "LEFT", -8, 0)
  else
    local holder = PSS.Layout and PSS.Layout.barHolderFrame
    if holder then frame:SetPoint("BOTTOMLEFT", holder, "TOPRIGHT", 12, 8)
    else frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230) end
  end
end
H.Place = Place

local function Build()
  if frame then return end
  frame = CreateFrame("Frame", "PetSkillScoutHawkTimer", UIParent)
  frame:SetSize(2 * SIZE + GAP, SIZE)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if PetSkillScoutDB and x then PetSkillScoutDB.hawkPos = {x = x, y = y} end
  end)
  for i = 1, H.MAX do
    local b = Square(frame)
    b:SetPoint("LEFT", frame, "LEFT", (i - 1) * (SIZE + GAP), 0)
    bars[i] = b
  end
  Place()
end

-- A glow frame on every action button that holds Summon Hawk (own texture,
-- the button itself is not touched).
local function ButtonsWithHawk()
  local out = {}
  local spell = DB().hawkSpell
  if not spell or not GetActionInfo then return out end
  for _, prefix in ipairs({"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
      "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button"}) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      local action = b and Plain(b.action) or (b and b.GetAttribute and Plain(Call(b.GetAttribute, b, "action")))
      if b and b:IsVisible() and type(action) == "number" then
        local kind, id = Call(GetActionInfo, action)
        if Plain(kind) == "spell" and Plain(id) == spell then out[#out + 1] = b end
      end
    end
  end
  return out
end

local function SetButtonGlow(on)
  for _, g in pairs(glows) do g:Hide() end
  if not on then return end
  for _, b in ipairs(ButtonsWithHawk()) do
    local g = glows[b]
    if not g then
      g = CreateFrame("Frame", nil, UIParent)
      g:SetFrameStrata("HIGH")
      local t = g:CreateTexture(nil, "OVERLAY")
      t:SetTexture(FLAT); t:SetAllPoints()
      g.t = t
      glows[b] = g
    end
    g:ClearAllPoints(); g:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2); g:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    local a = Accent()
    g.t:SetVertexColor(a[1], a[2], a[3], 0.35)
    g:Show()
  end
end

-- What the game itself says about the hawks: summons kept in the totem
-- slots (GetTotemInfo) and auras on you. Each found hawk: its real expiry.
-- Only when the game gives nothing is the 18 s from your cast used.
local function HawkName(name)
  if type(name) ~= "string" or Secret(name) then return false end
  local n = name:lower()
  return n:find("hawk", 1, true) ~= nil or n:find("яструб", 1, true) ~= nil
end

function H:ReadGame()
  local out, src = {}, nil
  if GetTotemInfo then
    for i = 1, (MAX_TOTEMS or 4) + 1 do
      local have, name, start, dur = Call(GetTotemInfo, i)
      have, name, start, dur = Plain(have), Plain(name), Plain(start), Plain(dur)
      if have and HawkName(name) and type(start) == "number" and type(dur) == "number" and dur > 0 then
        out[#out + 1] = start + dur
        src = "totem"
      end
    end
  end
  if #out == 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok or type(a) ~= "table" then break end
      local name, exp, n = Plain(a.name), Plain(a.expirationTime), Plain(a.applications)
      if HawkName(name) and type(exp) == "number" and exp > 0 then
        -- One aura per hawk, or one aura with a stack count.
        local count = (type(n) == "number" and n > 1) and math.min(n, H.MAX) or 1
        for _ = 1, count do out[#out + 1] = exp end
        src = "aura"
      end
    end
  end
  table.sort(out)
  return out, src
end

function H:Update()
  if not self:Enabled() then if frame then frame:Hide() end SetButtonGlow(false) return end
  Build()
  local now = Now()
  local live = {}
  local game, src = self:ReadGame()
  self.source = src
  if src then
    live = game
  else
    for _, t in ipairs(self.hawks) do if t > now then live[#live + 1] = t end end
  end
  self.hawks = src and self.hawks or live
  local inCombat = UnitAffectingCombat and Plain(Call(UnitAffectingCombat, "player"))
  local show = #live > 0 or (inCombat and DB().hawkSpell)
  frame:SetShown(show and true or false)
  if show and not DB().hawkPos then Place() end
  local a = Accent()
  local soon = #live < self.MAX or (live[1] and live[1] - now <= self:Refresh())
  local want = show and soon and inCombat
  local tex = DB().hawkSpell and ((C_Spell and C_Spell.GetSpellTexture and Plain(Call(C_Spell.GetSpellTexture, DB().hawkSpell)))
    or (GetSpellTexture and Plain(Call(GetSpellTexture, DB().hawkSpell))))
  for i = 1, self.MAX do
    local b = bars[i]
    local t = live[i]
    b.icon:SetTexture(tex or 132172)
    b.num:SetText(tostring(i))
    if t then
      local left = math.max(0, t - now)
      b.icon:SetDesaturated(false); b.icon:SetAlpha(1)
      -- "~": an estimate (the game did not report this hawk).
      b.text:SetText(string.format(self.source and "%.0f" or "~%.0f", left))
      local low = left <= self:Refresh()
      b.text:SetTextColor(low and 1 or 1, low and 0.45 or 0.95, low and 0.3 or 0.85)
      b.shade:SetHeight(math.max(0.01, (SIZE - 2) * (1 - left / self.LIFE)))
      b.shade:Show()
    else
      b.icon:SetDesaturated(true); b.icon:SetAlpha(0.45)
      b.text:SetText("")
      b.shade:Hide()
    end
    -- Edge: the theme's thin dark line; 2 px accent glow when to recast.
    if want and (not t or (t - now) <= self:Refresh()) then Edge(b, a[1], a[2], a[3], 1, 2)
    else Edge(b, 0, 0, 0, 1, 1) end
  end
  if want ~= self.glowing then
    self.glowing = want
    SetButtonGlow(want)
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "PLAYER_TOTEM_UPDATE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit ~= "player" then return end
    if IsHawk(Plain(spellID)) then H:Cast() end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then H.hawks = {} end
  if event == "PLAYER_TOTEM_UPDATE" then H.source = H.source or "totem" end
  pcall(H.Update, H)
end)
ev.pssKey = "HawkTimer"
local tick = 0
ev:SetScript("OnUpdate", function(_, e)
  tick = tick + (e or 0)
  if tick < 0.2 then return end
  tick = 0
  if #H.hawks > 0 or H.glowing or H.source or (frame and frame:IsShown()) then pcall(H.Update, H) end
end)

-- /pss hawk: what the game reports right now (summon slots and your buffs).
function H:Diag()
  PSS:Print("Summon Hawk spell: " .. tostring(DB().hawkSpell) .. ", data from: " .. tostring(self.source or "your casts (estimate)"))
  if GetTotemInfo then
    for i = 1, (MAX_TOTEMS or 4) + 1 do
      local have, name, start, dur = Call(GetTotemInfo, i)
      if Plain(have) then PSS:Print(string.format("  slot %d: %s, %s s", i, tostring(Plain(name)), tostring(Plain(dur)))) end
    end
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok or type(a) ~= "table" then break end
      local exp = Plain(a.expirationTime)
      PSS:Print(string.format("  buff: %s x%s, %s s left", tostring(Plain(a.name)), tostring(Plain(a.applications)),
        type(exp) == "number" and exp > 0 and string.format("%.0f", exp - Now()) or "-"))
    end
  end
end
