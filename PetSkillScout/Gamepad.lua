-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Gamepad support, step 1 (separate from the themes, changes nothing in them):
-- * detects whether a gamepad is enabled / being used (PSS.Gamepad.active),
-- * fires PSS.Gamepad:OnChange callbacks so theme code can adapt later,
-- * /pss gamepad prints what the client reports and which game frames of the
--   gamepad interface are on screen, to build the gamepad layouts on facts.
local PSS = PetSkillScout
PSS.Gamepad = {active = false, enabled = false, callbacks = {}}
local GP = PSS.Gamepad

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

-- Gamepad turned on in the client settings.
function GP:Enabled()
  if C_GamePad and C_GamePad.IsEnabled then
    local v = Plain(Call(C_GamePad.IsEnabled))
    if v ~= nil then return v and true or false end
  end
  local cv = GetCVar and Plain(Call(GetCVar, "GamePadEnable"))
  return cv == "1"
end

-- A gamepad is connected and was the last input.
function GP:InUse()
  if not self:Enabled() then return false end
  if self.lastActive ~= nil then return self.lastActive end
  -- No input event yet: a connected, active device counts as in use.
  if C_GamePad and C_GamePad.GetActiveDeviceID then
    return Plain(Call(C_GamePad.GetActiveDeviceID)) ~= nil
  end
  return false
end

-- Theme code subscribes here: fn(active) runs out of combat when it changes.
function GP:OnChange(fn) self.callbacks[#self.callbacks + 1] = fn end

local function Update()
  GP.enabled = GP:Enabled()
  local now = GP:InUse()
  if now == GP.active then return end
  if InCombatLockdown and InCombatLockdown() then GP.pending = true return end
  GP.active = now
  for _, fn in ipairs(GP.callbacks) do pcall(fn, now) end
end
GP.Update = Update

-- Visible frames that belong to the gamepad interface (by name).
function GP:Frames()
  local out = {}
  local f = EnumerateFrames and EnumerateFrames()
  local n = 0
  while f and n < 20000 do
    n = n + 1
    local ok, name = pcall(f.GetName, f)
    if ok and type(name) == "string" and (name:find("GamePad") or name:find("Gamepad") or name:find("Console")
        or name:find("Controller") or name:find("Cursor")) then
      local okS, shown = pcall(f.IsVisible, f)
      if okS and shown then out[#out + 1] = name end
    end
    f = EnumerateFrames(f)
  end
  table.sort(out)
  return out
end

-- Full dump of the gamepad interface for building the themed layout:
-- every visible frame near the bottom of the screen (action buttons and
-- their holders): name, parent, type, size, position, protected, icon.
-- Saved to PetSkillScoutDB.gamepadDiag (read from disk after /reload).
function GP:Dump()
  local out = {}
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local f = EnumerateFrames and EnumerateFrames()
  local n = 0
  while f and n < 40000 do
    n = n + 1
    local okV, vis = pcall(f.IsVisible, f)
    if okV and vis then
      local okB, l, b, w, h = pcall(f.GetRect, f)
      if okB and l and b and w and h and w > 4 and h > 4 and w < sw * 0.8 and b < sh * 0.45 then
        local okN, name = pcall(f.GetName, f)
        local parent = f.GetParent and f:GetParent()
        local pname = parent and select(2, pcall(parent.GetName, parent))
        local okT, kind = pcall(f.GetObjectType, f)
        local prot = f.IsProtected and select(2, pcall(f.IsProtected, f))
        local action = f.GetAttribute and select(2, pcall(f.GetAttribute, f, "action"))
        local icon = f.icon or f.Icon
        local tex = icon and icon.GetTexture and select(2, pcall(icon.GetTexture, icon))
        if not (type(name) == "string" and name:find("^PetSkillScout")) then
          out[#out + 1] = string.format("%s|%s|%s|%.0f,%.0f %.0fx%.0f|%s|%s|%s",
            tostring(name), tostring(pname), tostring(okT and kind), l, b, w, h,
            prot and "P" or "-", tostring(action), tostring(tex))
        end
      end
    end
    f = EnumerateFrames(f)
  end
  table.sort(out)
  if PetSkillScoutDB then
    PetSkillScoutDB.gamepadDiag = {t = time and time() or 0, screen = string.format("%.0fx%.0f", sw, sh),
      scale = UIParent:GetEffectiveScale(), enabled = self:Enabled(), inUse = self:InUse(), frames = out}
  end
  return #out
end

-- /pss gamepad
function GP:Print()
  local dumped = self:Dump()
  PSS:Print("gamepad: saved " .. dumped .. " frames of the lower screen for the layout (do /reload to write them to disk)")
  local api = C_GamePad and "yes" or "no"
  local dev = C_GamePad and C_GamePad.GetActiveDeviceID and Plain(Call(C_GamePad.GetActiveDeviceID))
  local devs = C_GamePad and C_GamePad.GetAllDeviceIDs and Call(C_GamePad.GetAllDeviceIDs)
  PSS:Print(string.format("gamepad: C_GamePad %s, enabled %s, active device %s, devices %s, last input gamepad %s",
    api, tostring(self:Enabled()), tostring(dev), type(devs) == "table" and #devs or "?", tostring(self.lastActive)))
  local cvars = {}
  for _, k in ipairs({"GamePadEnable", "GamePadCursorAutoEnable", "GamePadEmulateShift", "GamePadCameraYawSpeed"}) do
    cvars[#cvars + 1] = k .. "=" .. tostring(GetCVar and Plain(Call(GetCVar, k)))
  end
  PSS:Print("gamepad cvars: " .. table.concat(cvars, ", "))
  local frames = self:Frames()
  PSS:Print("gamepad frames on screen (" .. #frames .. "): " .. (#frames > 0 and table.concat(frames, ", ", 1, math.min(#frames, 25)) or "none"))
end

local ev = CreateFrame("Frame")
GP.frame = ev
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED",
    "CVAR_UPDATE", "PLAYER_REGEN_ENABLED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1)
  if event == "GAME_PAD_ACTIVE_CHANGED" then
    GP.lastActive = Plain(a1) and true or false
  elseif event == "GAME_PAD_DISCONNECTED" then
    GP.lastActive = false
  elseif event == "PLAYER_REGEN_ENABLED" then
    if not GP.pending then return end
    GP.pending = false
  elseif event == "CVAR_UPDATE" and not (type(a1) == "string" and a1:find("GamePad")) then
    return
  end
  pcall(Update)
end)
