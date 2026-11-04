-- Buffs and debuffs in the interface theme (part of the "units" layout).
--   * Player: the Blizzard buff and debuff frames are kept (right-click to
--     cancel a buff stays a Blizzard action) but moved above the player
--     frame (buffs first row, debuffs above) and restyled: cropped square
--     icons, thin theme border (debuffs in their type colour), small
--     duration and stack texts.
--   * Target: own row above the target frame - its debuffs first (type
--     colour border, yours bright, others dimmed), then its buffs (useful
--     for Tranquilizing Shot). Display only, with tooltips.
-- Moving the Blizzard frames happens out of combat only.
local PSS = PetSkillScout
PSS.Auras = {}
local A = PSS.Auras

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"

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
local function F(t, k) local v = type(t) == "table" and t[k]; return type(v) == "table" and v or nil end

local function Skin() return PSS.Skin end
local function Col(k)
  local S = Skin()
  return S and S.colours and S.colours[k] or {0.3, 0.3, 0.3, 1}
end

local DEBUFF_COLOURS = {
  Magic = {0.20, 0.60, 1.00}, Curse = {0.60, 0.00, 1.00}, Disease = {0.60, 0.40, 0.00},
  Poison = {0.00, 0.60, 0.00}, none = {0.80, 0.00, 0.00},
}
A.DEBUFF_COLOURS = DEBUFF_COLOURS

local function Font(fs, size)
  if type(fs) == "table" and fs.SetFont then pcall(fs.SetFont, fs, FONT, size, "OUTLINE") end
end

local function EdgeColour(bd, c)
  if not (bd and c) then return end
  for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

---------------------------------------------------------------------------
-- Player: Blizzard buff / debuff frames restyled and moved
---------------------------------------------------------------------------
local styled = setmetatable({}, {__mode = "k"})

-- One aura button (modern AuraButton or classic BuffButtonN / DebuffButtonN).
function A:StyleButton(b, debuff)
  local S = Skin()
  if type(b) ~= "table" or not (S and S.active) then return end
  local name = b.GetName and b:GetName()
  local icon = F(b, "Icon") or F(b, "icon") or (name and G(name .. "Icon"))
  -- Modern aura buttons are taller than wide (room for the duration), so
  -- the icon gets its own square box at the top of the button.
  if not b.pssSide then
    local side = icon and icon.GetWidth and Plain(icon:GetWidth()) or 0
    if type(side) ~= "number" or side < 8 then side = Plain(b:GetWidth()) or 30 end
    b.pssSide = side
  end
  local side = b.pssSide
  local box = b.pssBox
  if not box and not InCombat() then
    box = CreateFrame("Frame", nil, b)
    box:SetSize(side, side)
    box:SetPoint("TOP", b, "TOP", 0, 0)
    box:SetFrameLevel(b:GetFrameLevel())
    b.pssBox = box
  end
  if icon then
    if icon.SetTexCoord then pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92) end
    if box and not InCombat() and icon.ClearAllPoints then
      pcall(icon.ClearAllPoints, icon)
      pcall(icon.SetPoint, icon, "TOPLEFT", box, "TOPLEFT", 1, -1)
      pcall(icon.SetPoint, icon, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    end
  end
  -- Round / gold borders of the stock buttons.
  local border = F(b, "DebuffBorder") or F(b, "Border") or (name and G(name .. "Border"))
  local typeColour
  if border then
    if border.GetVertexColor then
      local ok, r, g, bl = pcall(border.GetVertexColor, border)
      if ok and type(r) == "number" and not Secret(r) then typeColour = {r, g, bl, 1} end
    end
    S.Fade(border)
  end
  for _, k in ipairs({"TempEnchantBorder", "Symbol"}) do
    local r = F(b, k) or (name and G(name .. k))
    if r and k == "TempEnchantBorder" then S.Fade(r) end
  end
  local bd = S:Backdrop(box or b, "slot", {0, 0, 0, 0}, "OVERLAY")
  if bd and bd.bg.SetDrawLayer then pcall(bd.bg.SetDrawLayer, bd.bg, "BACKGROUND", -8) end
  if debuff then EdgeColour(bd, typeColour or DEBUFF_COLOURS.none) else EdgeColour(bd, Col("edge")) end
  local dur = F(b, "Duration") or (name and G(name .. "Duration"))
  if dur then
    Font(dur, 9)
    if not InCombat() then
      pcall(dur.ClearAllPoints, dur)
      pcall(dur.SetPoint, dur, "TOP", box or b, "BOTTOM", 0, -1)
    end
  end
  local count = F(b, "Count") or (name and G(name .. "Count"))
  if count then
    Font(count, 10)
    if not InCombat() then
      pcall(count.ClearAllPoints, count)
      pcall(count.SetPoint, count, "BOTTOMRIGHT", box or b, "BOTTOMRIGHT", -1, 2)
    end
  end
  styled[b] = true
end

local function Container(frame)
  return F(frame, "AuraContainer") or frame
end

function A:StyleAll()
  local S = Skin()
  if not (S and S.active and self.on) then return end
  for _, def in ipairs({{"BuffFrame", false}, {"DebuffFrame", true}}) do
    local f = G(def[1])
    if f then
      local c = Container(f)
      for _, child in ipairs({c:GetChildren()}) do
        local t = child.GetObjectType and child:GetObjectType()
        if t == "Button" or t == "Frame" then
          -- Debuff buttons inside BuffFrame (classic) carry "Debuff" in the name.
          local name = child.GetName and child:GetName() or ""
          self:StyleButton(child, def[2] or (type(name) == "string" and name:find("Debuff") ~= nil))
        end
      end
    end
  end
  for i = 1, 40 do
    local b = G("BuffButton" .. i)
    if b then self:StyleButton(b, false) end
    local d = G("DebuffButton" .. i)
    if d then self:StyleButton(d, true) end
  end
  for i = 1, 3 do
    local t = G("TempEnchant" .. i)
    if t then self:StyleButton(t, false) end
  end
end

-- Bottom-up rows: the first row sits right above the player frame, more
-- rows grow upwards; debuffs start above the last buff row. Blizzard lays
-- the buttons out top-down, so after each of its updates the shown buttons
-- are re-anchored in Blizzard's order (layoutIndex, else screen position).
local PER_ROW_PLAYER = 8

local function Shown(b) return b and b.IsShown and b:IsShown() end

local function Collect(frame, classicPrefix)
  local list = {}
  if frame then
    for _, c in ipairs({Container(frame):GetChildren()}) do
      local t = c.GetObjectType and c:GetObjectType()
      if (t == "Button" or t == "Frame") and Shown(c) and c ~= F(frame, "CollapseAndExpandButton") then
        list[#list + 1] = c
      end
    end
  end
  if #list == 0 and classicPrefix then
    for i = 1, 40 do
      local b = G(classicPrefix .. i)
      if Shown(b) then list[#list + 1] = b end
    end
  end
  table.sort(list, function(a, b)
    local la, lb = Plain(a.layoutIndex), Plain(b.layoutIndex)
    if type(la) == "number" and type(lb) == "number" then return la < lb end
    local ta, tb = Plain(a.GetTop and a:GetTop()) or 0, Plain(b.GetTop and b:GetTop()) or 0
    if math.abs(ta - tb) > 2 then return ta > tb end
    return (Plain(a.GetRight and a:GetRight()) or 0) > (Plain(b.GetRight and b:GetRight()) or 0)
  end)
  return list
end

-- Places a list from baseY (pixels above the frame top) upwards; returns
-- the pixel height used.
local function Stack(list, anchor, baseY)
  if #list == 0 then return 0 end
  local used = 0
  for k, b in ipairs(list) do
    local scale = Plain(b.GetEffectiveScale and b:GetEffectiveScale()) or 1
    local ascale = Plain(anchor.GetEffectiveScale and anchor:GetEffectiveScale()) or 1
    local ratio = ascale / scale -- anchor pixels -> button units
    local side = b.pssSide or Plain(b:GetWidth()) or 30
    local h = Plain(b:GetHeight()) or side
    local step, rowH = side + 4, math.max(h, side + 12) + 2
    local col, row = (k - 1) % PER_ROW_PLAYER, math.floor((k - 1) / PER_ROW_PLAYER)
    pcall(b.ClearAllPoints, b)
    pcall(b.SetPoint, b, "BOTTOMRIGHT", anchor, "TOPRIGHT", -col * step, baseY * ratio + row * rowH)
    used = math.max(used, (row + 1) * rowH / ratio)
  end
  return used
end

function A:Arrange()
  if not self.on then return end
  local LY = PSS.Layout
  local player = LY and LY.units and LY.units.player
  if not player then return end
  -- Leave room for the XP bar when it sits on top of the player frame.
  local xpShown = LY.xpBar and LY.xpBar:IsShown() and (LY.xpOffset or 0) or 0
  local base = 6 + xpShown
  local used = Stack(Collect(G("BuffFrame"), "BuffButton"), player, base)
  Stack(Collect(G("DebuffFrame"), "DebuffButton"), player, base + used + (used > 0 and 4 or 0))
end

-- Above the player frame: buffs, then debuffs; right aligned with it.
function A:Place()
  if not self.on or InCombat() then return end
  local LY = PSS.Layout
  local player = LY and LY.units and LY.units.player
  if not player then return end
  local buffs, debuffs = G("BuffFrame"), G("DebuffFrame")
  if buffs then
    pcall(buffs.ClearAllPoints, buffs)
    pcall(buffs.SetPoint, buffs, "BOTTOMRIGHT", player, "TOPRIGHT", 0, 22)
    if buffs.SetScale then pcall(buffs.SetScale, buffs, 0.8) end
  end
  if debuffs then
    pcall(debuffs.ClearAllPoints, debuffs)
    pcall(debuffs.SetPoint, debuffs, "BOTTOMRIGHT", buffs or player, "TOPRIGHT", 0, buffs and 16 or 22)
    if debuffs.SetScale then pcall(debuffs.SetScale, debuffs, 0.8) end
  end
  for _, n in ipairs({"TemporaryEnchantFrame"}) do
    local f = G(n)
    if f then
      pcall(f.ClearAllPoints, f)
      pcall(f.SetPoint, f, "BOTTOMRIGHT", player, "TOPLEFT", -54, 22)
    end
  end
  local collapse = buffs and F(buffs, "CollapseAndExpandButton")
  if collapse and LY.Park then LY.Park(collapse) end
end

---------------------------------------------------------------------------
-- Target: own aura row
---------------------------------------------------------------------------
local ICON, GAP, PER_ROW = 24, 3, 9
local row, icons = nil, {}

local function AuraAt(unit, i, filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local a = Call(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
    if type(a) ~= "table" then return nil end
    return a.icon, a.applications, a.duration, a.expirationTime, a.dispelName, a.sourceUnit, a.auraInstanceID
  end
  if UnitAura then
    local name, icon, count, dtype, duration, expires, source = Call(UnitAura, unit, i, filter)
    if name == nil then return nil end
    return icon, count, duration, expires, dtype, source, nil
  end
end
A.AuraAt = AuraAt

local function NewIcon(i)
  local b = CreateFrame("Frame", nil, row)
  b:SetSize(ICON, ICON)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
  if ok and cd then
    cd:SetAllPoints(b.icon)
    if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end
    if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers, cd, false) end
    b.cd = cd
  end
  b.count = b:CreateFontString(nil, "OVERLAY")
  Font(b.count, 10)
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  local S = Skin()
  if S then
    b.bd = S:Backdrop(b, "slot", {0, 0, 0, 0}, "OVERLAY")
    if b.bd and b.bd.bg.SetDrawLayer then pcall(b.bd.bg.SetDrawLayer, b.bd.bg, "BACKGROUND", -8) end
  end
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    if not self.index then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local done = false
    if self.auraID and GameTooltip.SetUnitAuraByAuraInstanceID then
      done = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, "target", self.auraID)
    end
    if not done and GameTooltip.SetUnitAura then pcall(GameTooltip.SetUnitAura, GameTooltip, "target", self.index, self.filter) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local col, line = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
  b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -col * (ICON + GAP), line * (ICON + GAP))
  icons[i] = b
  return b
end

local function SetCooldown(b, duration, expires, auraID)
  if not b.cd then return end
  local d, e = Plain(duration), Plain(expires)
  if type(d) == "number" and type(e) == "number" and d > 0 then
    pcall(b.cd.SetCooldown, b.cd, e - d, d)
    b.cd:Show()
    return
  end
  -- Secret values: the client can drive the swipe itself.
  if auraID and C_UnitAuras and C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
    local obj = Call(C_UnitAuras.GetAuraDuration, "target", auraID)
    if obj and pcall(b.cd.SetCooldownFromDurationObject, b.cd, obj) then b.cd:Show(); return end
  end
  if b.cd.Clear then pcall(b.cd.Clear, b.cd) end
  b.cd:Hide()
end

function A:UpdateTarget()
  if not (row and self.on) then return end
  local S = Skin()
  if not Plain(Call(UnitExists, "target")) then row:Hide(); return end
  row:Show()
  local n, max = 0, PER_ROW * 2
  local function add(filter, debuff)
    for i = 1, 40 do
      if n >= max then return end
      local icon, count, duration, expires, dtype, source, auraID = AuraAt("target", i, filter)
      if icon == nil then return end
      n = n + 1
      local b = icons[n] or NewIcon(n)
      pcall(b.icon.SetTexture, b.icon, icon)
      b.index, b.filter, b.auraID = i, filter, auraID
      local c = Plain(count)
      b.count:SetText((type(c) == "number" and c > 1) and tostring(c) or "")
      SetCooldown(b, duration, expires, auraID)
      local mine = Plain(source) == "player" or Plain(source) == "pet"
      if S and b.bd then
        if debuff then
          local dc = DEBUFF_COLOURS[Plain(dtype) or "none"] or DEBUFF_COLOURS.none
          EdgeColour(b.bd, dc)
        else
          EdgeColour(b.bd, Col("edge"))
        end
      end
      -- Your own debuffs bright, everyone else's dimmed.
      b.icon:SetDesaturated(debuff and source ~= nil and not Secret(source) and not mine or false)
      b:SetAlpha((debuff and source ~= nil and not Secret(source) and not mine) and 0.7 or 1)
      b:Show()
    end
  end
  add("HARMFUL", true)
  add("HELPFUL", false)
  for i = n + 1, #icons do icons[i]:Hide() end
  self:PlaceTargetRow()
end

-- Above the target frame, above the tameable badge when it is shown.
function A:PlaceTargetRow()
  if not row then return end
  local LY = PSS.Layout
  local target = LY and LY.units and LY.units.target
  if not target then return end
  row:ClearAllPoints()
  local badge = target.badgeBg
  if badge and badge:IsShown() then
    row:SetPoint("BOTTOMRIGHT", badge, "TOPRIGHT", 0, 4)
  else
    row:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 20)
  end
end

local function BuildTargetRow()
  local LY = PSS.Layout
  local target = LY and LY.units and LY.units.target
  if not target or row then return end
  row = CreateFrame("Frame", "PetSkillScoutTargetAuras", target)
  row:SetSize(PER_ROW * (ICON + GAP) - GAP, ICON * 2 + GAP)
  A.row, A.icons = row, icons
end

---------------------------------------------------------------------------
-- Setup (called by Layout when the units part is applied)
---------------------------------------------------------------------------
local hooked = false
function A:Apply()
  self.on = true
  BuildTargetRow()
  self:Place()
  self:StyleAll()
  self:Arrange()
  if not hooked and hooksecurefunc then
    hooked = true
    local function restyle() pcall(A.StyleAll, A); pcall(A.Arrange, A) end
    for _, n in ipairs({"BuffFrame", "DebuffFrame"}) do
      local f = G(n)
      if f then
        for _, m in ipairs({"UpdateAuraButtons", "Update", "UpdateGridLayout"}) do
          if type(f[m]) == "function" then pcall(hooksecurefunc, f, m, restyle) end
        end
        -- The modern container lays itself out on its own (dirty flag).
        local c = F(f, "AuraContainer")
        if c then
          for _, m in ipairs({"Layout", "UpdateGridLayout"}) do
            if type(c[m]) == "function" then pcall(hooksecurefunc, c, m, restyle) end
          end
        end
      end
    end
    for _, fn in ipairs({"BuffFrame_Update", "AuraButton_Update", "BuffFrame_UpdateAllBuffAnchors"}) do
      if type(_G[fn]) == "function" then hooksecurefunc(fn, restyle) end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
      pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", function() pcall(A.Place, A) end, A)
    end
  end
  self:UpdateTarget()
end

A.frame = CreateFrame("Frame")
for _, e in ipairs({"UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED"}) do
  pcall(A.frame.RegisterEvent, A.frame, e)
end
A.frame:SetScript("OnEvent", function(_, event, unit)
  if not A.on then return end
  if event == "PLAYER_REGEN_ENABLED" then
    pcall(A.Place, A); pcall(A.StyleAll, A); pcall(A.Arrange, A)
  elseif event == "PLAYER_TARGET_CHANGED" or unit == "target" then
    pcall(A.UpdateTarget, A)
  elseif unit == "player" then
    pcall(A.StyleAll, A); pcall(A.Arrange, A)
  end
end)
