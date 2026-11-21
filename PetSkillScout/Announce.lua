-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Short notes to your group and guild about your own rare events (rare tamed,
-- last rank of a skill, collection milestones), signed {PetSkillScout}.
-- Never to public channels or whispers, no links. At most one event in 5
-- minutes, nothing in combat or instances; a skipped event is not sent later.
-- Each event goes out once ever. Settings: Network.
local PSS = PetSkillScout
PSS.Announce = {}
local A = PSS.Announce
A.GAP = 300
A.TAG = "{PetSkillScout} "
A.MILESTONES = {look10 = true, look25 = true, look50 = true, look100 = true, lookAll = true,
  family1 = true, family5 = true, families = true, friend30 = true, friend100 = true, route10 = true}
local lastSent, lastSpot = -1e9, -1e9

local function L(k) return PSS:L(k) end
local function Clean(v) return (tostring(v or ""):gsub("|", "")) end
local function Flag(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, ...)
  return ok and PSS.Plain(v) and true or false
end
local function On(key)
  local db = PetSkillScoutDB
  return db and db.announceOn ~= false and (not key or db[key] ~= false)
end
local function Say(text, chan)
  local say = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if say then pcall(say, text, chan) end
end
local function GroupChannel()
  if Flag(IsInRaid) then return "RAID" end
  if Flag(IsInGroup) then return "PARTY" end
end

-- Send one line to the group and the guild. "Last" keeps it for /pss announce:
-- typed by you, it goes out even where the client blocks automatic messages.
function A:Post(text)
  text = (self.TAG .. Clean(text)):sub(1, 250)
  self.last = text
  if PetSkillScoutDB and PetSkillScoutDB.announceBlocked then
    PSS:Print(string.format(L("annBlocked"), text))
    return
  end
  local chan = GroupChannel()
  if chan then Say(text, chan) end
  if Flag(IsInGuild) then Say(text, "GUILD") end
end

-- Once per key, within the limits.
function A:Event(key, opt, text)
  if not On(opt) then return false end
  local seen = PetSkillScoutDB.announced or {}
  PetSkillScoutDB.announced = seen
  if seen[key] then return false end
  seen[key] = true
  local now = GetTime and GetTime() or 0
  if now - lastSent < self.GAP or Flag(InCombatLockdown) or Flag(IsInInstance) then return false end
  lastSent = now
  self:Post(text)
  return true
end

function A:Rare(entry)
  return self:Event("rare:" .. tostring(entry.id), "announceRare", string.format(L("annRare"), entry.name))
end
function A:Achievement(id)
  if not self.MILESTONES[id] then return false end
  return self:Event("ach:" .. id, "announceMilestone", string.format(L("annMilestone"), L("ach_" .. id)))
end

-- Skills at their last rank. The first look only records what is already there.
function A:CheckRanks()
  local db, pet = PetSkillScoutDB, PSS.MyPet
  if not (db and pet and pet.active) then return end
  local first = not db.announceRanksInit
  db.announced = db.announced or {}
  for _, s in ipairs(pet.spells or {}) do
    local ranks = s.key and s.rank and PSS.Ranks and PSS.Ranks[s.key]
    if ranks and #ranks > 1 and s.rank >= #ranks then
      local key = "rank:" .. s.key
      if first then db.announced[key] = true
      else self:Event(key, "announceRank", string.format(L("annRank"), PSS:NameAbility(s.key), s.rank)) end
    end
  end
  db.announceRanksInit = true
end

-- A rare's place, on your own click, to the group only.
function A:ShareRare(entry)
  local chan = GroupChannel()
  if not chan then PSS:Print(L("annNoGroup")) return false end
  local now = GetTime and GetTime() or 0
  if now - lastSpot < 10 then return false end
  lastSpot = now
  local p = entry.beast and entry.beast.spawnPoints and entry.beast.spawnPoints[1]
  local text = string.format(L("annSpot"), entry.name, entry.zone or "?")
  if p then text = text .. string.format(" %.1f, %.1f", p[1], p[2]) end
  self.last = (self.TAG .. Clean(text)):sub(1, 250)
  Say(self.last, chan)
  return true
end

function A:SendLast()
  if self.last then Say(self.last, GroupChannel() or "GUILD") end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PET_BAR_UPDATE"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" and PetSkillScoutDB and not PetSkillScoutDB.announceNotice then
    PetSkillScoutDB.announceNotice = true
    if C_Timer and C_Timer.After then C_Timer.After(12, function() PSS:Print(L("annNotice")) end) end
  end
  PSS:Soon("announce-ranks", function() pcall(A.CheckRanks, A) end, 3)
end)
