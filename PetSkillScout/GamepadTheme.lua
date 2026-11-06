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
GT.UNIT_Y, GT.CAST_Y = 360, 320

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
  for key, x in pairs({player = -250, target = 250}) do
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
      strip:SetShown(ok and shown and true or false)
      if not hooked[f] and f.HookScript then
        hooked[f] = true
        pcall(f.HookScript, f, "OnShow", function() if PSS.GamepadTheme then PSS.GamepadTheme.Sync() end end)
        pcall(f.HookScript, f, "OnHide", function() if PSS.GamepadTheme then PSS.GamepadTheme.Sync() end end)
      end
    end
  end
end
GT.Sync = function() pcall(SyncStrips) end

function GT:Apply(active)
  if InCombat() then self.pending = active; return end
  self.pending = nil
  self.active = active
  local L = LY()
  if not (L and L.applied and L.applied.units) then SyncStrips() return end
  PlaceUnits(active)
  SyncStrips()
end

if PSS.Gamepad and PSS.Gamepad.OnChange then
  PSS.Gamepad:OnChange(function(active) GT:Apply(active) end)
end

local ev = CreateFrame("Frame")
GT.frame = ev
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if GT.pending ~= nil then GT:Apply(GT.pending) end
    return
  end
  -- After the theme is built: apply the current mode once.
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function()
      local active = PSS.Gamepad and PSS.Gamepad:InUse() or false
      GT:Apply(active)
    end)
  end
end)
