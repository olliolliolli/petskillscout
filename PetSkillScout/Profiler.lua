-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- /pss cpu: one-minute CPU check inside the game. The OnUpdate and OnEvent
-- handlers of PetSkillScout's own frames (found by their source file) and
-- the delayed passes (PSS:Soon) are timed with debugprofilestop; after 60 s
-- the original handlers are put back and the 10 heaviest are printed to
-- chat (milliseconds per second of play). Protected frames are skipped and
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

function P:Start(secs, login)
  if self.cost then PSS:Print("CPU check is already running.") return end
  self.login = login
  self.peak = login and {} or nil
  if InCombatLockdown and InCombatLockdown() then PSS:Print("Not in combat - try again after the fight.") return end
  if not (debugprofilestop and EnumerateFrames) then PSS:Print("This client has no profiling functions.") return end
  self.cost, self.saved = {}, {}
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
  PSS:Print(string.format("CPU check: %d frames watched for %d s. Play normally.", n, secs or DURATION))
  C_Timer.After(secs or DURATION, function() P:Stop() end)
end

function P:Stop()
  if not self.cost then return end
  if InCombatLockdown and InCombatLockdown() then C_Timer.After(5, function() P:Stop() end) return end
  for _, s in ipairs(self.saved) do pcall(s[1].SetScript, s[1], s[2], s[3]) end
  local secs = math.max(1, (debugprofilestop() - self.started) / 1000)
  local list, total = {}, 0
  for k, v in pairs(self.cost) do list[#list + 1] = {k, v}; total = total + v end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  self.cost, self.saved = nil, nil
  if self.login then
    -- Login check: total milliseconds and the longest single pass (a freeze).
    local peak = self.peak or {}
    PSS:Print(string.format("Login CPU: files loaded in %.0f ms, %.0f ms of work in %d s. Heaviest:", P.loadMs or -1, total, secs))
    for i = 1, math.min(10, #list) do
      PSS:Print(string.format("%2d. %.0f ms total, longest %.0f ms  %s", i, list[i][2], peak[list[i][1]] or 0, list[i][1]))
    end
    local keep = {at = time and time() or 0, login = true, load = P.loadMs, total = total, top = {}}
    for i = 1, math.min(25, #list) do keep.top[i] = {list[i][1], list[i][2], peak[list[i][1]] or 0} end
    if PetSkillScoutDB then PetSkillScoutDB.cpuLog = keep end
    self.cost, self.saved, self.peak, self.login = nil, nil, nil, nil
    PSS:Print("Saved. Do /reload so the developer can read it.")
    return
  end
  PSS:Print(string.format("CPU check: %.2f ms per second in total. Heaviest:", total / secs))
  for i = 1, math.min(10, #list) do
    PSS:Print(string.format("%2d. %.3f ms/s  %s", i, list[i][2] / secs, list[i][1]))
  end
  -- Kept in SavedVariables too (last check only), for the developer.
  local keep = {at = time and time() or 0, total = total / secs, top = {}}
  for i = 1, math.min(20, #list) do keep.top[i] = {list[i][1], list[i][2] / secs} end
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
