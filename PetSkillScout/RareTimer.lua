-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Rare respawn timers. When a rare dies (combat log or its corpse is seen) or is
-- tamed, the time is stored; the next live sighting closes the interval. The
-- intervals seen so far give the respawn window shown in the Rares tab. Kills
-- are shared with guild / group members (Sync), so timers fill in faster.
-- There is no built-in respawn data: windows are only what was observed.
local PSS = PetSkillScout
PSS.RareTimer = {}
local T = PSS.RareTimer
local MAX_HIST, STALE = 10, 3 * 86400

local function Now() return time and time() or 0 end
local function L(key) return PSS:L(key) end

local function Store()
  if not PetSkillScoutDB then return nil end
  PetSkillScoutDB.rareTimers = PetSkillScoutDB.rareTimers or {}
  return PetSkillScoutDB.rareTimers
end

function T:Get(entry)
  local s = entry and Store()
  return s and s[entry.id]
end

local function Refresh()
  if PSS.UI and PSS.UI.view == "rares" and PSS.UI.UpdateRares then PSS.UI:UpdateRares() end
  if PSS.RareMap then PSS.RareMap:Refresh() end
end

-- how: "kill", "corpse", "tame". who: player name (nil = this player).
-- remote: received from Sync, so it is not sent again. Returns true when stored.
function T:MarkGone(entry, how, who, t, remote)
  local s = Store()
  if not (s and entry) then return false end
  t = t or Now()
  local rec = s[entry.id] or {hist = {}}
  -- Same death reported twice (combat log + corpse, or by several players).
  if rec.gone and math.abs(t - rec.gone) < 300 then return false end
  -- Seen alive after this time: the report is older than the current spawn.
  if rec.alive and rec.alive > t + 60 then return false end
  rec.gone, rec.how, rec.by, rec.alerted = t, how, who, nil
  s[entry.id] = rec
  if not remote and PSS.Sync and PSS.Sync.BroadcastKill then PSS.Sync:BroadcastKill(entry, rec) end
  Refresh()
  return true
end

-- A live sighting (own or shared). Closes an open interval.
function T:SeenAlive(entry, t)
  local s = Store()
  if not (s and entry) then return end
  t = t or Now()
  local rec = s[entry.id] or {hist = {}}
  if rec.gone and t - rec.gone > 120 then
    rec.hist = rec.hist or {}
    table.insert(rec.hist, t - rec.gone)
    while #rec.hist > MAX_HIST do table.remove(rec.hist, 1) end
    rec.gone, rec.how, rec.by, rec.alerted = nil, nil, nil, nil
  end
  if not rec.alive or t > rec.alive then rec.alive = t end
  s[entry.id] = rec
end

-- Shortest and longest observed respawn interval (seconds) and the count.
function T:Window(entry)
  local rec = self:Get(entry)
  local hist = rec and rec.hist
  if not (hist and #hist > 0) then return nil end
  local lo, hi = hist[1], hist[1]
  for _, v in ipairs(hist) do
    if v < lo then lo = v end
    if v > hi then hi = v end
  end
  return lo, hi, #hist
end

-- Elapsed seconds since the rare was last gone, or nil.
function T:Elapsed(entry)
  local rec = self:Get(entry)
  if not (rec and rec.gone) then return nil end
  local elapsed = Now() - rec.gone
  if elapsed < 0 or elapsed > STALE then return nil end
  return elapsed, rec
end

function T:Duration(sec)
  sec = math.max(0, math.floor(sec or 0))
  if sec < 60 then return string.format(L("unitMin"), 1) end
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h == 0 then return string.format(L("unitMin"), m) end
  if m == 0 then return string.format(L("unitHour"), h) end
  return string.format(L("unitHour"), h) .. " " .. string.format(L("unitMin"), m)
end

local function Range(a, b)
  if math.abs(a - b) < 300 then return T:Duration(a) end
  return T:Duration(a) .. " - " .. T:Duration(b)
end

-- Text for the Rares tab and tooltips, plus a state:
-- "wait" (not yet), "open" (window running), "late" (past the window),
-- "unknown" (gone, no data yet), "info" (only history).
function T:Text(entry)
  local elapsed, rec = self:Elapsed(entry)
  local lo, hi, n = self:Window(entry)
  if not elapsed then
    if lo then return string.format(L("timerHistory"), Range(lo, hi), n), "info" end
    return nil
  end
  local key = rec.how == "tame" and "timerTamed" or (rec.how == "corpse" and "timerCorpse" or "timerKilled")
  local head = string.format(L(key), self:Duration(elapsed))
  if rec.by then head = head .. " (" .. rec.by .. ")" end
  if not lo then return head .. "  ·  " .. L("timerUnknown"), "unknown" end
  if elapsed < lo then
    return head .. "  ·  " .. string.format(L("timerBackIn"), Range(lo - elapsed, hi - elapsed)), "wait"
  elseif elapsed <= hi then
    return head .. "  ·  " .. L("timerOpen"), "open"
  end
  return head .. "  ·  " .. L("timerLate"), "late"
end

-- One short line for the rare tiles (the full text goes in the tooltip).
function T:ShortText(entry)
  local text, state = self:Text(entry)
  if not text then return nil end
  local elapsed = self:Elapsed(entry)
  local lo = self:Window(entry)
  if state == "info" then return string.format(L("timerShortInfo"), self:Duration(lo)), state end
  local ago = self:Duration(elapsed)
  if state == "wait" then return string.format(L("timerShortWait"), self:Duration(lo - elapsed)), state end
  if state == "open" then return string.format(L("timerShortOpen"), ago), state end
  if state == "late" then return string.format(L("timerShortLate"), ago), state end
  return string.format(L("timerShortUnknown"), ago), state
end

-- Seconds until the window opens (negative when already open), for sorting.
function T:Remaining(entry)
  local elapsed = self:Elapsed(entry)
  local lo = self:Window(entry)
  if elapsed and lo then return lo - elapsed end
end

-- Window alerts for wanted rares -----------------------------------------------
local function AlertsOn() return not PetSkillScoutDB or PetSkillScoutDB.rareTimerAlert ~= false end

function T:Tick()
  if not AlertsOn() then return end
  local R = PSS.RarePets
  local s = Store()
  if not (R and s) then return end
  if not R.entries or #R.entries == 0 then R:Build() end
  for _, entry in ipairs(R.entries) do
    local rec = s[entry.id]
    if rec and rec.gone and not rec.alerted and R:IsWanted(entry) and not R:IsCollected(entry) then
      local elapsed = self:Elapsed(entry)
      local lo = self:Window(entry)
      if elapsed and lo and elapsed >= lo then
        rec.alerted = true
        local text = string.format(L("timerAlert"), entry.name, entry.zone or "?")
        PSS:Print(text)
        if RaidNotice_AddMessage and RaidWarningFrame then
          pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(text), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
        end
        Refresh()
      end
    end
  end
end

-- Detection ------------------------------------------------------------------
local function EntryForGUID(guid)
  local R = PSS.RarePets
  if not (R and type(guid) == "string" and R.NpcIDFromGUID) then return nil end
  local npc = R.NpcIDFromGUID(guid)
  if not npc then return nil end
  if not R.byNpcID or not next(R.byNpcID) then R:Build() end
  return R.byNpcID[npc]
end
T.EntryForGUID = EntryForGUID

local TAME_SPELL = 1515
local lastTame = -1e9
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok then return name end
  end
  if GetSpellInfo then
    local ok, name = pcall(GetSpellInfo, id)
    if ok then return name end
  end
end

local function IsTameSpell(spellID)
  if type(spellID) ~= "number" or (PSS.IsSecret and PSS.IsSecret(spellID)) then return false end
  if spellID == TAME_SPELL then return true end
  local name, tame = SpellName(spellID), SpellName(TAME_SPELL)
  return name ~= nil and name == tame
end

-- Pet GUID "Pet-0-...-<npcID>-<uid>"; returns the creature ID.
local function PetNpc()
  local guid = UnitGUID and UnitGUID("pet")
  if type(guid) ~= "string" then return nil, nil end
  local _, _, _, _, _, id = strsplit("-", guid)
  return tonumber(id), guid
end

local function OnPet()
  local npc, guid = PetNpc()
  if not (npc and PetSkillScoutDB) then return end
  PetSkillScoutDB.seenPets = PetSkillScoutDB.seenPets or {}
  if PetSkillScoutDB.seenPets[guid] then return end
  PetSkillScoutDB.seenPets[guid] = true
  local R = PSS.RarePets
  if not R then return end
  if not R.byNpcID or not next(R.byNpcID) then R:Build() end
  local entry = R.byNpcID[npc]
  if not entry then return end
  -- A new pet that is a rare: add it to the collection.
  if not R:IsCollected(entry) then
    R:SetCollected(entry, true)
    PSS:Print(string.format(L("timerCollected"), entry.name))
  end
  local now = GetTime and GetTime() or 0
  if now - lastTame < 90 then T:MarkGone(entry, "tame") end
  Refresh()
end

T.frame = CreateFrame("Frame")
-- No combat log: registering it is restricted on this client. Deaths are seen
-- from corpses (target, mouseover, nameplates) and from other players' reports.
for _, e in ipairs({"UNIT_PET", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START"}) do
  pcall(T.frame.RegisterEvent, T.frame, e)
end
local function OnEvent(event, unit, a2, a3)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if not CombatLogGetCurrentEventInfo then return end
    local _, sub, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if sub == "UNIT_DIED" or sub == "PARTY_KILL" then
      local entry = EntryForGUID(destGUID)
      if entry then T:MarkGone(entry, "kill") end
    end
  elseif event == "UNIT_PET" then
    if unit == "player" then OnPet() end
  elseif unit == "player" and IsTameSpell(a3) then
    -- UNIT_SPELLCAST_*: unit, castGUID, spellID
    lastTame = GetTime and GetTime() or 0
    T.lastTame = lastTame
  end
end
T.frame:SetScript("OnEvent", function(_, event, ...) pcall(OnEvent, event, ...) end)
local tick = 0
T.frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + (elapsed or 0)
  if tick < 20 then return end
  tick = 0
  pcall(T.Tick, T)
end)
T.frame.pssKey = "RareTimer"
PSS:Every(T.frame, 5)
