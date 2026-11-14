-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Gamepad layout for the theme (step 2). Separate from Layout.lua: it only
-- runs while a gamepad is in use (PSS.Gamepad) and puts everything back when
-- you switch to keyboard and mouse.
-- * Player / target frames move up above the gamepad button clusters
--   (unless you placed them yourself), the cast bar too.
-- * The theme's backing strips of the micro menu and bags hide whenever the
--   game hides those bars (the gamepad interface does).
local PSS = PetSkillScout
PSS.GamepadTheme = {}
local GT = PSS.GamepadTheme

-- Heights above the screen bottom (UI units) in gamepad mode.
-- Matched to the game's own gamepad layout: the player frame sits left above
-- the left button cluster (target mirrored on the right), the cast bar
-- above the centre buttons.
GT.UNIT_Y, GT.UNIT_X, GT.CAST_Y = 300, 325, 360

local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function LY() return PSS.Layout end

-- Unit frames that have no position saved by you.
local function Free(key)
  local L = LY()
  return L and L.movables and L.movables[key] and not (L.Saved and L:Saved(key))
end

local function PlaceUnits(active)
  local L = LY()
  if not (L and L.units) then return end
  for key, x in pairs({player = -GT.UNIT_X, target = GT.UNIT_X}) do
    local f = L.units[key]
    if f and Free(key) then
      pcall(f.ClearAllPoints, f)
      if active then pcall(f.SetPoint, f, "BOTTOM", UIParent, "BOTTOM", x, GT.UNIT_Y)
      else
        for _, p in ipairs(L.movables[key].default or {}) do pcall(f.SetPoint, f, unpack(p)) end
      end
    end
  end
  local cb = _G.CastingBarFrame or _G.PlayerCastingBarFrame
  if cb and active then
    pcall(cb.ClearAllPoints, cb)
    pcall(cb.SetPoint, cb, "BOTTOM", UIParent, "BOTTOM", 0, GT.CAST_Y)
  end
end

-- Strips follow the visibility of their bar (both modes; harmless with mouse).
local hooked = {}
local function SyncStrips()
  local L = LY()
  if not (L and L.strips) then return end
  for name, strip in pairs(L.strips) do
    local f = _G[name]
    if f and strip.SetShown then
      local ok, shown = pcall(f.IsVisible, f)
      -- Gamepad mode: the bars are replaced by the gamepad interface (the bag
      -- bar can stay "visible" with its buttons gone) - no backing at all.
      strip:SetShown(ok and shown and not GT.active and true or false)
      if not hooked[f] and f.HookScript then
        hooked[f] = true
        pcall(f.HookScript, f, "OnShow", function() if PSS.GamepadTheme then PSS.GamepadTheme.Sync() end end)
        pcall(f.HookScript, f, "OnHide", function() if PSS.GamepadTheme then PSS.GamepadTheme.Sync() end end)
      end
    end
  end
end
GT.Sync = function() pcall(SyncStrips) end

-- Gamepad action buttons in the theme ---------------------------------------
-- The game's gamepad bar: GamepadMainActionBarFrame > ...PageUnit > four
-- groups (Left/Top/Right/Bottom ...CenteredAnchor...Bar) of 8 buttons, two
-- class action buttons, and a big round 256x128 backing behind each group.
-- Buttons get the same look as the theme's action bars (square border,
-- cropped icon, theme fonts); the round backings are faded; the whole bar is
-- scaled down (only out of combat; positions are left to the game).
GT.SCALE = 0.85
local skinned = setmetatable({}, {__mode = "k"})
local function Children(f)
  local ok, list = pcall(function() return {f:GetChildren()} end)
  return ok and list or {}
end
local function Regions(f)
  local ok, list = pcall(function() return {f:GetRegions()} end)
  return ok and list or {}
end
-- Button glyphs: the game draws them into the round backing art, which is
-- hidden, so each button gets a small label in its corner. In every group of
-- 8 buttons: 1-4 = d-pad (left, up, right, down), 5-8 = face buttons
-- (X left, Y up, B right, A down) - read from the gamepad frame layout.
local GLYPH = {
  {"\226\134\144", {0.85, 0.85, 0.85}}, {"\226\134\145", {0.85, 0.85, 0.85}},
  {"\226\134\146", {0.85, 0.85, 0.85}}, {"\226\134\147", {0.85, 0.85, 0.85}},
  {"X", {0.35, 0.6, 1}}, {"Y", {1, 0.85, 0.2}}, {"B", {1, 0.35, 0.3}}, {"A", {0.4, 0.9, 0.35}},
}
local function Label(b, index)
  local g = GLYPH[index]
  if not g or b.pssGlyph then return end
  local fs = b:CreateFontString(nil, "OVERLAY")
  -- Noto Sans (shipped with the addon) has the arrow characters.
  local font = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
  pcall(fs.SetFont, fs, font, 10, "OUTLINE")
  fs:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  fs:SetText(g[1])
  fs:SetTextColor(g[2][1], g[2][2], g[2][3], 1)
  b.pssGlyph = fs
end

local function SkinTree(f, depth)
  if depth > 6 then return end
  for _, c in ipairs(Children(f)) do
    local _, name = pcall(c.GetName, c)
    local _, kind = pcall(c.GetObjectType, c)
    if type(name) == "string" and (name:find("ActionButton%d+$") or name:find("ClassAction$")) then
      if not skinned[c] and PSS.Skin and PSS.Skin.SkinActionButton then
        skinned[c] = true
        GT.sample = GT.sample or c
        pcall(PSS.Skin.SkinActionButton, c)
        local idx = tonumber(name:match("Bar[A-Za-z]*ActionButton(%d+)$"))
        if idx then pcall(Label, c, idx) end
      end
    elseif kind == "Frame" and not name then
      -- Unnamed art frames: the round backings (256x128) are faded; small ones
      -- (button labels LT / RT / LB...) stay.
      local okS, w, h = pcall(function() return c:GetWidth(), c:GetHeight() end)
      if okS and type(w) == "number" and w >= 120 and h >= 60 and PSS.Skin and PSS.Skin.Fade then
        -- Only the big round art; the small button glyphs (A, B, X, Y, LT,
        -- RT...) drawn on the same backing stay, a bit dimmer and smaller look.
        for _, r in ipairs(Regions(c)) do
          local okR, rw, rh = pcall(function() return r:GetWidth(), r:GetHeight() end)
          if okR and type(rw) == "number" and (rw >= 48 or rh >= 48) then
            pcall(PSS.Skin.Fade, r)
          elseif r.SetAlpha then
            pcall(r.SetAlpha, r, 0.85)
          end
        end
      end
    end
    SkinTree(c, depth + 1)
  end
end
function GT:SkinBar()
  local root = _G.GamepadMainActionBarFrame
  if not (root and PSS.Skin and PSS.Skin.active) then return false end
  -- Protected buttons: never touched in combat, redone when combat ends.
  if InCombat() then self.skinPending = true; return false end
  self.skinPending = nil
  -- The game rebuilds these buttons on input changes and alt-tab: always redo.
  wipe(skinned)
  pcall(SkinTree, root, 0)
  if not InCombat() and root.SetScale then
    local want = (PetSkillScoutDB and tonumber(PetSkillScoutDB.gamepadScale)) or self.SCALE
    pcall(root.SetScale, root, want)
  end
  if not self.rootHooked and root.HookScript then
    self.rootHooked = true
    pcall(root.HookScript, root, "OnShow", function() PSS:Soon("gp-skin", function() GT:SkinBar() end, 0.2) end)
  end
  return true
end

function GT:Apply(active)
  if InCombat() then self.pending = active; return end
  self.pending = nil
  self.active = active
  local L = LY()
  if active then pcall(self.SkinBar, self) end
  if not (L and L.applied and L.applied.units) then SyncStrips() return end
  PlaceUnits(active)
  SyncStrips()
end

if PSS.Gamepad and PSS.Gamepad.OnChange then
  PSS.Gamepad:OnChange(function(active) GT:Apply(active) end)
end

-- True when the game put its own look back on the bar.
function GT.Reverted(alpha, scale, want)
  if type(alpha) == "number" and alpha > 0.01 then return true end
  return type(scale) == "number" and type(want) == "number" and math.abs(scale - want) > 0.01
end
local keep = CreateFrame("Frame")
keep:SetScript("OnUpdate", function()
  if not GT.active or InCombat() or not GT.sample then return end
  local root = _G.GamepadMainActionBarFrame
  local okS, shown = pcall(function() return root and root:IsVisible() end)
  if not (okS and shown) then return end
  local okN, nt = pcall(GT.sample.GetNormalTexture, GT.sample)
  local okA, alpha = pcall(function() return nt and nt:GetAlpha() end)
  local okR, scale = pcall(root.GetScale, root)
  local want = (PetSkillScoutDB and tonumber(PetSkillScoutDB.gamepadScale)) or GT.SCALE
  if GT.Reverted(okN and okA and PSS.Plain(alpha), okR and PSS.Plain(scale), want) then pcall(GT.SkinBar, GT) end
end)
keep.pssKey = "gamepad look"
PSS:Every(keep, 2)

local ev = CreateFrame("Frame")
GT.frame = ev
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if GT.pending ~= nil then GT:Apply(GT.pending) end
    if GT.skinPending then pcall(GT.SkinBar, GT) end
    return
  end
  -- After the theme is built: apply the current mode once.
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function()
      local active = PSS.Gamepad and PSS.Gamepad:InUse() or false
      GT:Apply(active)
      -- The gamepad bar may be built a bit later: try the skin again.
      if active then C_Timer.After(5, function() pcall(GT.SkinBar, GT) end) end
    end)
  end
end)
