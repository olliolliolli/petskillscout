-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- /pss cpu: one-minute CPU check inside the game. The OnUpdate and OnEvent
-- handlers of PetSkillScout's own frames (found by their source file) and
-- the delayed passes (PSS:Soon) are timed with debugprofilestop; after 60 s
-- the original handlers are put back and the 10 heaviest are printed to
-- chat (milliseconds per second of play), plus the heaviest module
-- functions (Inventory, Bags, Nav, maps, plates...). Protected frames are skipped and
-- nothing is changed in combat.
local PSS = PetSkillScout
PSS.Profiler = {}
local P = PSS.Profiler

local DURATION = 60

local function Ours(f)
  if f.IsForbidden and f:IsForbidden() then return nil end
  if f.IsProtected and f:IsProtected() then return nil end
  local loc
  if f.GetSourceLocation then
    local ok, v = pcall(f.GetSourceLocation, f)
    if ok and type(v) == "string" then loc = v end
  end
  if loc then
    if loc:find("PetSkillScout", 1, true) then return (loc:match("([^/\\]+%.lua:%d+)") or loc) end
    return nil
  end
  local name = f.GetName and f:GetName()
  if type(name) == "string" and name:find("^PetSkillScout") then return name end
end

function P:Add(key, ms)
  if not self.cost then return end
  self.cost[key] = (self.cost[key] or 0) + ms
  if self.peak and ms > (self.peak[key] or 0) then self.peak[key] = ms end
end

local function Wrap(f, script, key)
  local orig = f:GetScript(script)
  if type(orig) ~= "function" then return end
  P.saved[#P.saved + 1] = {f, script, orig}
  local name = key .. " " .. script .. (script == "OnEvent" and "" or "")
  f:SetScript(script, function(self, a, ...)
    local t = debugprofilestop()
    orig(self, a, ...)
    local k = name
    if script == "OnEvent" and type(a) == "string" then k = name .. " " .. a end
    P:Add(k, debugprofilestop() - t)
  end)
end

-- Function-level timing: every function in PetSkillScout's module tables
-- (PSS.Inventory, PSS.Bags, PSS.Nav...) and PSS's own methods is swapped for
-- a timed copy while the check runs. Times are inclusive (a function that
-- calls others carries their time too), so they are listed apart from frames.
local SKIP = {Profiler = true, Print = true, Timed = true, Soon = true, L = true}
local function Done(t, key, ...)
  if not P.calls then return ... end
  P:Add(key, debugprofilestop() - t)
  P.calls[key] = (P.calls[key] or 0) + 1
  return ...
end
local function WrapFn(tbl, k, key)
  local orig = tbl[k]
  local w = function(...) return Done(debugprofilestop(), key, orig(...)) end
  tbl[k] = w
  P.fns[#P.fns + 1] = {tbl, k, orig, w}
end
local function WrapModules()
  local n = 0
  for name, v in pairs(PSS) do
    if type(v) == "function" and not SKIP[name] then
      WrapFn(PSS, name, "fn PSS:" .. name); n = n + 1
    elseif type(v) == "table" and not SKIP[name] and v ~= PSS and not (v.IsObjectType or v.GetObjectType) then
      for k, f in pairs(v) do
        if type(f) == "function" and type(k) == "string" then WrapFn(v, k, "fn " .. name .. ":" .. k); n = n + 1 end
      end
    end
  end
  return n
end

function P:Start(secs, login)
  if self.cost then PSS:Print("CPU check is already running.") return end
  self.login = login
  self.peak = login and {} or nil
  if InCombatLockdown and InCombatLockdown() then PSS:Print("Not in combat - try again after the fight.") return end
  if not (debugprofilestop and EnumerateFrames) then PSS:Print("This client has no profiling functions.") return end
  self.cost, self.saved, self.fns, self.calls = {}, {}, {}, {}
  local nf = WrapModules()
  local f = EnumerateFrames()
  local n = 0
  while f do
    local key = Ours(f)
    if key then
      n = n + 1
      Wrap(f, "OnUpdate", key)
      Wrap(f, "OnEvent", key)
    end
    f = EnumerateFrames(f)
  end
  self.started = debugprofilestop()
  PSS:Print(string.format("CPU check: %d frames and %d functions watched for %d s. Play normally.", n, nf, secs or DURATION))
  C_Timer.After(secs or DURATION, function() P:Stop() end)
end

function P:Stop()
  if not self.cost then return end
  if InCombatLockdown and InCombatLockdown() then C_Timer.After(5, function() P:Stop() end) return end
  for _, s in ipairs(self.saved) do pcall(s[1].SetScript, s[1], s[2], s[3]) end
  for _, w in ipairs(self.fns) do if w[1][w[2]] == w[4] then w[1][w[2]] = w[3] end end
  local secs = math.max(1, (debugprofilestop() - self.started) / 1000)
  local list, fl, total = {}, {}, 0
  for k, v in pairs(self.cost) do
    if k:sub(1, 3) == "fn " then fl[#fl + 1] = {k:sub(4), v, self.calls[k] or 0}
    else list[#list + 1] = {k, v}; total = total + v end
  end
  local byCost = function(a, b) return a[2] > b[2] end
  table.sort(list, byCost); table.sort(fl, byCost)
  self.cost, self.saved, self.fns, self.calls = nil, nil, nil, nil
  if self.login then
    -- Login check: total milliseconds and the longest single pass (a freeze).
    local peak = self.peak or {}
    PSS:Print(string.format("Login CPU: files loaded in %.0f ms, %.0f ms of work in %d s. Heaviest:", P.loadMs or -1, total, secs))
    for i = 1, math.min(10, #list) do
      PSS:Print(string.format("%2d. %.0f ms total, longest %.0f ms  %s", i, list[i][2], peak[list[i][1]] or 0, list[i][1]))
    end
    PSS:Print("Heaviest functions (inclusive):")
    for i = 1, math.min(10, #fl) do
      PSS:Print(string.format("%2d. %.0f ms total, longest %.0f ms, %d calls  %s", i, fl[i][2], peak["fn " .. fl[i][1]] or 0, fl[i][3], fl[i][1]))
    end
    local keep = {at = time and time() or 0, login = true, load = P.loadMs, total = total, top = {}, fns = {}}
    for i = 1, math.min(25, #list) do keep.top[i] = {list[i][1], list[i][2], peak[list[i][1]] or 0} end
    for i = 1, math.min(40, #fl) do keep.fns[i] = {fl[i][1], fl[i][2], peak["fn " .. fl[i][1]] or 0, fl[i][3]} end
    if PetSkillScoutDB then PetSkillScoutDB.cpuLog = keep end
    self.cost, self.saved, self.peak, self.login = nil, nil, nil, nil
    PSS:Print("Saved. Do /reload so the developer can read it.")
    return
  end
  PSS:Print(string.format("CPU check: %.2f ms per second in total. Heaviest:", total / secs))
  for i = 1, math.min(10, #list) do
    PSS:Print(string.format("%2d. %.3f ms/s  %s", i, list[i][2] / secs, list[i][1]))
  end
  PSS:Print("Heaviest functions (inclusive, ms/s, calls/s):")
  for i = 1, math.min(10, #fl) do
    PSS:Print(string.format("%2d. %.3f ms/s  %.1f/s  %s", i, fl[i][2] / secs, fl[i][3] / secs, fl[i][1]))
  end
  -- Kept in SavedVariables too (last check only), for the developer.
  local keep = {at = time and time() or 0, total = total / secs, top = {}, fns = {}}
  for i = 1, math.min(20, #list) do keep.top[i] = {list[i][1], list[i][2] / secs} end
  for i = 1, math.min(40, #fl) do keep.fns[i] = {fl[i][1], fl[i][2] / secs, fl[i][3] / secs} end
  if PetSkillScoutDB then PetSkillScoutDB.cpuLog = keep end
  PSS:Print("Saved. Do /reload so the developer can read it.")
end

-- "/pss cpu login": the check starts as soon as all files are loaded, so the
-- login work (PLAYER_LOGIN, PLAYER_ENTERING_WORLD, first passes) is measured.
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
  if name ~= PSS.name then return end
  self:UnregisterAllEvents()
  if PSS.loadStart and debugprofilestop then P.loadMs = debugprofilestop() - PSS.loadStart end
  if PetSkillScoutDB and PetSkillScoutDB.cpuAtLogin then
    PetSkillScoutDB.cpuAtLogin = nil
    P:Start(30, true)
  end
end)
