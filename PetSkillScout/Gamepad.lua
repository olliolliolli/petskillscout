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
  local out, err = {}, nil
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local function one(f)
    local okV, vis = pcall(f.IsVisible, f)
    if not (okV and vis) then return end
    local okB, l, b, w, h = pcall(f.GetRect, f)
    if not (okB and type(l) == "number" and type(b) == "number" and type(w) == "number" and type(h) == "number") then return end
    if Secret(l) or Secret(b) or Secret(w) or Secret(h) then return end
    if w <= 4 or h <= 4 or w >= sw * 0.8 or b >= sh * 0.45 then return end
    local _, name = pcall(f.GetName, f)
    if type(name) == "string" and name:find("^PetSkillScout") then return end
    local pname
    local okP, parent = pcall(f.GetParent, f)
    if okP and parent then local _, pn = pcall(parent.GetName, parent); pname = pn end
    local _, kind = pcall(f.GetObjectType, f)
    local _, prot = pcall(f.IsProtected, f)
    local action
    if f.GetAttribute then local _, a = pcall(f.GetAttribute, f, "action"); action = a end
    local tex
    local icon = rawget(f, "icon") or rawget(f, "Icon")
    if type(icon) == "table" and icon.GetTexture then local _, t = pcall(icon.GetTexture, icon); tex = t end
    out[#out + 1] = string.format("%s|%s|%s|%d,%d %dx%d|%s|%s|%s", tostring(name), tostring(pname), tostring(kind),
      math.floor(l + 0.5), math.floor(b + 0.5), math.floor(w + 0.5), math.floor(h + 0.5),
      prot and "P" or "-", tostring(action), tostring(tex))
  end
  local ok, e = pcall(function()
    local f = EnumerateFrames()
    local n = 0
    while f and n < 40000 and #out < 1500 do
      n = n + 1
      pcall(one, f)
      local okN, nxt = pcall(EnumerateFrames, f)
      f = okN and nxt or nil
    end
  end)
  if not ok then err = tostring(e) end
  table.sort(out)
  if PetSkillScoutDB then
    PetSkillScoutDB.gamepadDiag = {t = time and time() or 0, screen = string.format("%dx%d", math.floor(sw), math.floor(sh)),
      enabled = self:Enabled(), inUse = self:InUse(), err = err, frames = out}
  end
  return #out, err
end

-- /pss gamepad
function GP:Print()
  local okD, dumped, derr = pcall(self.Dump, self)
  if not okD then derr, dumped = tostring(dumped), 0 end
  PSS:Print("gamepad: saved " .. tostring(dumped) .. " frames of the lower screen" ..
    (derr and (" (error: " .. derr .. ")") or "") .. " - do /reload to write them to disk")
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
  local GN = PSS.GamepadNav
  PSS:Print("gamepad: game menu button " .. tostring(_G.PetSkillScoutGameMenuButton ~= nil))
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

-- The gamepad "Main Menu" is a radial wheel (Start button) whose frame names
-- are not documented: while a gamepad is in use, visible top-level frames
-- with menu-like names are recorded once (PetSkillScoutDB.gamepadMenus) with
-- their children, so the addon can later add its own entry there.
local watch = CreateFrame("Frame")
local wacc = 0
watch:SetScript("OnUpdate", function(_, e)
  wacc = wacc + (e or 0)
  if wacc < 1 then return end
  wacc = 0
  if not (GP.active and PetSkillScoutDB) then return end
  local seen = PetSkillScoutDB.gamepadMenus or {}
  local okK, kids = pcall(function() return {UIParent:GetChildren()} end)
  for _, f in ipairs(okK and kids or {}) do
    local okN, name = pcall(f.GetName, f)
    local okV, vis = pcall(f.IsVisible, f)
    if okN and type(name) == "string" and okV and vis and not seen[name]
       and (name:find("Radial") or name:find("Wheel") or name:find("Ring") or name:find("MainMenu") or name:find("Gamepad")) then
      local sub = {}
      local okC, ch = pcall(function() return {f:GetChildren()} end)
      for _, c in ipairs(okC and ch or {}) do
        local _, cn = pcall(c.GetName, c)
        local _, ck = pcall(c.GetObjectType, c)
        sub[#sub + 1] = tostring(cn) .. ":" .. tostring(ck)
        if #sub >= 40 then break end
      end
      local _, prot = pcall(f.IsProtected, f)
      seen[name] = {t = time and time() or 0, protected = prot and true or false, children = sub}
    end
  end
  PetSkillScoutDB.gamepadMenus = seen
end)

-- Radial menu internals (undocumented): while GamepadRadial is open, one
-- snapshot per distinct page goes to PetSkillScoutDB.gamepadRadial: its Lua
-- fields, the frame tree and visible texts, so an entry can be added properly.
local function RadialSnap(root)
  local lines, texts = {}, {}
  local function Fields(f)
    local out = {}
    local ok = pcall(function()
      for k, v in pairs(f) do
        if type(k) == "string" and k ~= "0" then
          local tv = type(v)
          if tv == "table" or tv == "function" then out[#out + 1] = k .. ":" .. tv:sub(1, 1)
          else out[#out + 1] = k .. "=" .. tostring(v) end
        end
        if #out >= 80 then break end
      end
    end)
    table.sort(out)
    return ok and table.concat(out, " ") or "?"
  end
  local function Walk(f, depth, path)
    if #lines >= 250 then return end
    local _, kind = pcall(f.GetObjectType, f)
    local _, vis = pcall(f.IsVisible, f)
    local _, w = pcall(f.GetWidth, f)
    local _, h = pcall(f.GetHeight, f)
    lines[#lines + 1] = string.format("%s %s vis=%s %dx%d | %s", path, tostring(kind), tostring(vis),
      tonumber(w) or 0, tonumber(h) or 0, Fields(f))
    local okR, regs = pcall(function() return {f:GetRegions()} end)
    for _, r in ipairs(okR and regs or {}) do
      local _, rk = pcall(r.GetObjectType, r)
      if rk == "FontString" then
        local _, t = pcall(r.GetText, r)
        local _, rv = pcall(r.IsVisible, r)
        if type(t) == "string" and t ~= "" and rv then texts[#texts + 1] = t end
      end
    end
    if depth >= 3 then return end
    local okC, ch = pcall(function() return {f:GetChildren()} end)
    for i, c in ipairs(okC and ch or {}) do Walk(c, depth + 1, path .. "." .. i) end
  end
  Walk(root, 0, "R")
  table.sort(texts)
  return table.concat(texts, ","), lines
end

local radialWatch, radialAcc = CreateFrame("Frame"), 0
radialWatch:SetScript("OnUpdate", function(_, e)
  radialAcc = radialAcc + (e or 0)
  if radialAcc < 0.4 then return end
  radialAcc = 0
  local r = _G.GamepadRadial
  if not (r and PetSkillScoutDB) then return end
  local okV, vis = pcall(r.IsVisible, r)
  if not (okV and vis) then return end
  local ok, key, lines = pcall(RadialSnap, r)
  local db = PetSkillScoutDB.gamepadRadial or {pages = {}, count = 0}
  if ok and not db.pages[key] and db.count < 8 then
    db.pages[key] = lines
    db.count = db.count + 1
    if not db.globals then
      local g = {}
      pcall(function()
        for k in pairs(_G) do
          if type(k) == "string" and (k:find("Radial") or k:find("MainMenuWheel")) then g[#g + 1] = k end
          if #g >= 100 then break end
        end
      end)
      db.globals = g
    end
  elseif not ok then db.err = tostring(key) end
  PetSkillScoutDB.gamepadRadial = db
end)
