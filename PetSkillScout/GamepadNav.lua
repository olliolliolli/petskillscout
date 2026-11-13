-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Gamepad control of the PetSkillScout window (separate module; mouse and
-- keyboard work as before). Only while a gamepad is in use and the window is
-- open, the window takes the gamepad buttons:
--   LB / RB        previous / next tab
--   D-pad          move the selection (nearest button in that direction)
--   A              press the selected button
--   B              close the window
--   X              back to the previous tab
--   Y              settings
-- A hint strip at the bottom of the window shows this. Secure buttons (feed
-- button) are skipped: they cannot be pressed from addon code.
-- Opening the window: a key binding ("Open PetSkillScout") that can be put on
-- a gamepad button in the game's key bindings, or the minimap button.
local PSS = PetSkillScout
PSS.GamepadNav = {}
local GN = PSS.GamepadNav

local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Frame() return _G.PetSkillScoutFrame end
local function L(k) return PSS:L(k) end

-- Clickable, visible, not secure buttons of the open view (and the tabs).
local function Collect()
  local root = Frame()
  local out = {}
  local function walk(f, depth)
    if depth > 12 then return end
    local okC, kids = pcall(function() return {f:GetChildren()} end)
    for _, c in ipairs(okC and kids or {}) do
      local okV, vis = pcall(c.IsVisible, c)
      if okV and vis then
        local okT, kind = pcall(c.GetObjectType, c)
        local _, prot = pcall(c.IsProtected, c)
        local clickable = okT and (kind == "Button" or kind == "CheckButton") and not prot
          and c.IsEnabled and select(2, pcall(c.IsEnabled, c)) and c.GetScript and c:GetScript("OnClick")
        if clickable then
          local okR, l, b, w, h = pcall(c.GetRect, c)
          if okR and l and w and w > 6 and h > 6 then out[#out + 1] = {f = c, x = l + w / 2, y = b + h / 2} end
        end
        walk(c, depth + 1)
      end
    end
  end
  if root then walk(root, 0) end
  return out
end

-- Selection highlight.
local box
local function Box()
  if box then return box end
  box = CreateFrame("Frame", nil, UIParent)
  box:SetFrameStrata("TOOLTIP")
  box:EnableMouse(false)
  local function edge(p1, p2, horiz)
    local t = box:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface/Buttons/WHITE8X8")
    t:SetVertexColor(1, 0.82, 0.2, 1)
    t:SetPoint(p1); t:SetPoint(p2)
    if horiz then t:SetHeight(2) else t:SetWidth(2) end
  end
  edge("TOPLEFT", "TOPRIGHT", true); edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  edge("TOPLEFT", "BOTTOMLEFT", false); edge("TOPRIGHT", "BOTTOMRIGHT", false)
  box:Hide()
  return box
end
function GN:Select(f)
  self.sel = f
  local b = Box()
  if not f then b:Hide() return end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
  b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
  b:Show()
  if GameTooltip and f.GetScript and f:GetScript("OnEnter") then pcall(f:GetScript("OnEnter"), f) end
end

-- Nearest button in a direction (dx, dy = -1/0/1, screen y grows upwards).
function GN:Move(dx, dy)
  local list = Collect()
  if #list == 0 then return end
  local cur
  for _, e in ipairs(list) do if e.f == self.sel then cur = e end end
  if not cur then self:Select(list[1].f) return end
  local best, bestScore
  for _, e in ipairs(list) do
    if e.f ~= cur.f then
      local vx, vy = e.x - cur.x, e.y - cur.y
      local along = vx * dx + vy * dy
      if along > 2 then
        local across = math.abs(vx * dy) + math.abs(vy * dx)
        local score = along + across * 2.5
        if not bestScore or score < bestScore then best, bestScore = e, score end
      end
    end
  end
  if best then
    if GameTooltip then GameTooltip:Hide() end
    self:Select(best.f)
  end
end

local function Tab(step)
  local UI = PSS.UI
  if not (UI and UI.tabs and #UI.tabs > 0) then return end
  local idx = 1
  for i, t in ipairs(UI.tabs) do if t.view == UI.view then idx = i end end
  idx = (idx - 1 + step) % #UI.tabs + 1
  UI:ShowView(UI.tabs[idx].view)
  GN:Select(nil)
end

function GN:OnButton(button)
  local UI = PSS.UI
  if button == "PADLSHOULDER" then Tab(-1)
  elseif button == "PADRSHOULDER" then Tab(1)
  elseif button == "PADDUP" then self:Move(0, 1)
  elseif button == "PADDDOWN" then self:Move(0, -1)
  elseif button == "PADDLEFT" then self:Move(-1, 0)
  elseif button == "PADDRIGHT" then self:Move(1, 0)
  elseif button == "PAD1" then
    local f = self.sel
    if f and f.Click and f:IsVisible() then pcall(f.Click, f, "LeftButton") end
  elseif button == "PAD2" then
    local fr = Frame()
    if fr then fr:Hide() end
  elseif button == "PAD3" then
    if UI and UI.lastView and UI.lastView ~= UI.view then UI:ShowView(UI.lastView) end
  elseif button == "PAD4" then
    if UI then UI:ShowView("settings") end
  else
    return false
  end
  return true
end

-- Hint strip at the bottom of the window.
local hint
local function Hint()
  local fr = Frame()
  if not fr then return nil end
  if hint then return hint end
  hint = CreateFrame("Frame", nil, fr)
  hint:SetHeight(20)
  -- Under the window, so it never covers the window's own footer text.
  hint:SetPoint("TOPLEFT", fr, "BOTTOMLEFT", 0, -2)
  hint:SetPoint("TOPRIGHT", fr, "BOTTOMRIGHT", 0, -2)
  hint:SetFrameLevel(fr:GetFrameLevel() + 50)
  local bg = hint:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface/Buttons/WHITE8X8")
  bg:SetVertexColor(0, 0, 0, 0.75)
  bg:SetAllPoints(hint)
  hint.text = hint:CreateFontString(nil, "OVERLAY")
  pcall(hint.text.SetFont, hint.text, "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf", 11, "")
  hint.text:SetPoint("CENTER")
  hint:Hide()
  return hint
end

-- Window open + gamepad in use: take the gamepad buttons.
function GN:Update()
  local fr = Frame()
  if not fr then return end
  local want = fr:IsShown() and PSS.Gamepad and PSS.Gamepad.active and not InCombat()
  if fr.EnableGamePadButton then pcall(fr.EnableGamePadButton, fr, want and true or false) end
  local h = Hint()
  if h then
    h.text:SetText(PSS:Safe(L("gpHint")))
    h:SetShown(want and true or false)
  end
  if not want then self:Select(nil) end
end

function GN:Hook()
  local fr = Frame()
  if not fr or self.hooked then return end
  self.hooked = true
  fr:HookScript("OnShow", function() GN:Update() end)
  fr:HookScript("OnHide", function() GN:Update() end)
  pcall(fr.SetScript, fr, "OnGamePadButtonDown", function(_, button) pcall(GN.OnButton, GN, button) end)
end

if PSS.Gamepad and PSS.Gamepad.OnChange then
  PSS.Gamepad:OnChange(function() GN:Hook(); GN:Update() end)
end

-- Key binding target (Bindings.xml): toggle the window.
function PetSkillScout_ToggleWindow()
  if PSS.UI and PSS.UI.Toggle then PSS.UI:Toggle() end
  GN:Hook(); GN:Update()
end

-- The window is created on first open (minimap button, /pss, binding).
if hooksecurefunc and PSS.UI then
  for _, m in ipairs({"Toggle", "Open"}) do
    if type(PSS.UI[m]) == "function" then pcall(hooksecurefunc, PSS.UI, m, function() GN:Hook(); GN:Update() end) end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function()
  GN:Hook()
  GN:Update()
end)

-- Opening the window without key bindings --------------------------------
-- 1) A "PetSkillScout" button under the game menu (Start / Menu button on
--    the gamepad), picked with the gamepad cursor. Own frame anchored below
--    the menu: the game's menu layout is not touched.
local menuButton
local function MenuButton()
  local gm = _G.GameMenuFrame
  if not gm or menuButton then return end
  menuButton = CreateFrame("Button", "PetSkillScoutGameMenuButton", UIParent, "UIPanelButtonTemplate")
  menuButton:SetSize(160, 26)
  menuButton:SetFrameStrata("DIALOG")
  menuButton:SetText("PetSkillScout")
  menuButton:SetScript("OnClick", function()
    -- The game menu is left to the game: closing it from addon code taints
    -- the gamepad UI. Our window opens above it; B closes the menu.
    PetSkillScout_ToggleWindow()
  end)
  menuButton:Hide()
  gm:HookScript("OnShow", function()
    menuButton:ClearAllPoints()
    menuButton:SetPoint("TOP", gm, "BOTTOM", 0, -6)
    menuButton:Show()
  end)
  gm:HookScript("OnHide", function() menuButton:Hide() end)
end
GN.MenuButton = MenuButton

-- (A stick combo was tried in 3.6.1; only the menu button is kept.)
function GN:ComboAvailable() return false end

local ev2 = CreateFrame("Frame")
ev2:RegisterEvent("PLAYER_ENTERING_WORLD")
ev2:SetScript("OnEvent", function() pcall(MenuButton) end)

-- 2) An entry on the gamepad Main Menu wheel (Start button). The wheel is the
-- game's own code, and writing into its tables would taint it and could break
-- what it opens. So nothing of it is changed: our icon sits on a free segment
-- of the current page, and the wheel is only read (which segment is chosen).
GN.ICON = "Interface\\AddOns\\PetSkillScout\\Textures\\PetSkillScoutLogo"

-- Index of the first free segment, nil when the page is full.
function GN.FreeSegment(radial)
  for i = 1, 8 do
    local seg = radial["Segment" .. i]
    if seg and seg.IsEmpty then
      local ok, empty = pcall(seg.IsEmpty, seg)
      if ok and empty then return i, seg end
    end
  end
end

-- The stick left our segment for the centre (not for another segment).
function GN.Released(was, on, index)
  return was and not on and (index == 0 or index == nil)
end

local mark
local function MarkWheel()
  local radial = _G.GamepadRadial
  if mark or not radial then return mark end
  mark = CreateFrame("Frame", nil, radial)
  mark:SetSize(60, 60)
  mark:SetFrameLevel(radial:GetFrameLevel() + 20)
  mark:EnableMouse(false)
  mark.icon = mark:CreateTexture(nil, "OVERLAY")
  mark.icon:SetSize(36, 36)
  mark.icon:SetPoint("CENTER")
  mark.icon:SetTexture(GN.ICON)
  mark.label = mark:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mark.label:SetPoint("TOP", mark.icon, "BOTTOM", 0, -2)
  mark.label:SetText("PetSkillScout")
  mark:Hide()
  local function Place()
    local i, seg = GN.FreeSegment(radial)
    mark.free = i
    if not i then mark:Hide() return end
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", seg, "CENTER")
    mark:Show()
  end
  local function Open()
    mark.was = false
    pcall(radial.Hide, radial)
    if C_Timer and C_Timer.After then C_Timer.After(0, function() PetSkillScout_ToggleWindow() end) end
  end
  local keeper = CreateFrame("Frame", nil, radial)
  keeper:SetScript("OnUpdate", function(_, elapsed)
    pcall(Place)
    local index = PSS.Plain(radial.currentIndex)
    local db = PetSkillScoutDB
    if db and type(index) == "number" then
      local log = db.gamepadWheel or {}
      log.free = mark.free
      log["i" .. index] = true
      db.gamepadWheel = log
    end
    -- Like the game's own entries: chosen when the stick is let go on it.
    local on = mark.free ~= nil and index == mark.free
    if GN.Released(mark.was, on, index) and not InCombat() then Open() end
    mark.was = on
  end)
  -- Closed by the game with our segment chosen (A or Start).
  pcall(radial.HookScript, radial, "OnHide", function()
    local open = mark.was and not PSS.Plain(radial.isCancelled)
    mark.was = false
    if open and not InCombat() and C_Timer and C_Timer.After then
      C_Timer.After(0, function() PetSkillScout_ToggleWindow() end)
    end
  end)
  return mark
end
GN.MarkWheel = MarkWheel

local wheelEv = CreateFrame("Frame")
pcall(wheelEv.RegisterEvent, wheelEv, "PLAYER_ENTERING_WORLD")
wheelEv:SetScript("OnEvent", function()
  if PetSkillScoutDB then PetSkillScoutDB.gamepadMenus, PetSkillScoutDB.gamepadRadial = nil, nil end
  pcall(MarkWheel)
  if C_Timer and C_Timer.After then C_Timer.After(5, function() pcall(MarkWheel) end) end
end)
