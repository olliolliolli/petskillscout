-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Look collection ("skins"), families and the pet log (where and when each pet
-- joined you). Looks are collected from your active pet, your stable and the
-- rares you tamed. Data: SkinData.lua.
local PSS = PetSkillScout
PSS.Collection = {}
local C = PSS.Collection

local function Now() return time and time() or 0 end

function C:Build()
  if self.looks then return end
  self.looks, self.byNpc, self.byId, self.families = {}, {}, {}, {}
  local A = PSS.Atlas
  if A then A:Build() end
  local rareNpc = {}
  local R = PSS.RarePets
  if R then
    if not R.entries or #R.entries == 0 then R:Build() end
    for _, e in ipairs(R.entries) do if e.beast.npcID then rareNpc[tonumber(e.beast.npcID)] = e end end
  end
  for _, row in ipairs(PSS.SkinData or {}) do
    local id, slug, npcs = row[1], row[2], row[3]
    local look = {id = id, slug = slug, npcs = npcs, beasts = {}, onlyRare = true, new = true}
    for _, npc in ipairs(npcs) do
      self.byNpc[npc] = look
      local rec = A and A:Get(npc)
      if rec then
        table.insert(look.beasts, rec)
        look.family = look.family or rec.family
        if not (rec.isRare or rareNpc[npc]) then look.onlyRare = false end
        -- "New in Forever" only when no classic beast has this look.
        if not rec.new then look.new = false end
        local lo, hi = rec.minLevel, rec.maxLevel or rec.minLevel
        if lo and (not look.minLevel or lo < look.minLevel) then look.minLevel = lo end
        if hi and (not look.maxLevel or hi > look.maxLevel) then look.maxLevel = hi end
        if not look.display and rec.displayID then look.display, look.npc = rec.displayID, npc end
      end
    end
    if #look.beasts == 0 then look.onlyRare, look.new = false, false end
    -- Named after one of its beasts (the slug from the source), else the first.
    for _, b in ipairs(look.beasts) do
      local s = b.name:lower():gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
      if s == slug then look.name, look.npc = b.name, b.npcID break end
    end
    look.name = look.name or (look.beasts[1] and look.beasts[1].name) or slug
    look.npc = look.npc or npcs[1]
    if look.family then
      self.families[look.family] = (self.families[look.family] or 0) + 1
      table.insert(self.looks, look)
      self.byId[id] = look
    end
  end
  table.sort(self.looks, function(a, b)
    if a.family ~= b.family then return PSS:NameFamily(a.family) < PSS:NameFamily(b.family) end
    return (a.minLevel or 0) < (b.minLevel or 0)
  end)
end

local function Store(key)
  PetSkillScoutDB[key] = PetSkillScoutDB[key] or {}
  return PetSkillScoutDB[key]
end

function C:IsCollected(look)
  return look and PetSkillScoutDB and PetSkillScoutDB.looks and PetSkillScoutDB.looks[look.id] ~= nil
end

-- Marks the look of a creature as collected. Returns the look when it is new.
function C:CollectNpc(npc, source)
  self:Build()
  local look = npc and self.byNpc[tonumber(npc)]
  if not (look and PetSkillScoutDB) then return nil end
  local looks = Store("looks")
  if looks[look.id] then return nil end
  looks[look.id] = {t = Now(), npc = tonumber(npc), src = source}
  if look.family then Store("familiesTamed")[look.family] = true end
  return look
end

function C:Counts()
  self:Build()
  local have, total = 0, #self.looks
  local looks = PetSkillScoutDB and PetSkillScoutDB.looks or {}
  for _, look in ipairs(self.looks) do if looks[look.id] then have = have + 1 end end
  return have, total
end

function C:FamilyCounts(family)
  self:Build()
  local have, total = 0, 0
  for _, look in ipairs(self.looks) do
    if look.family == family then
      total = total + 1
      if self:IsCollected(look) then have = have + 1 end
    end
  end
  return have, total
end

function C:FamiliesTamed()
  local n = 0
  for _ in pairs(PetSkillScoutDB and PetSkillScoutDB.familiesTamed or {}) do n = n + 1 end
  return n
end

function C:FamilyTotal()
  self:Build()
  local n = 0
  for _ in pairs(self.families) do n = n + 1 end
  return n
end

-- Nearest beast with this look (for the arrow).
function C:NearestBeast(look)
  local best, bestD
  local here = PSS.Nav and { PSS.Nav:PlayerPos() } or {}
  for _, b in ipairs(look.beasts) do
    if b.mapID and b.spawnPoints and #b.spawnPoints > 0 then
      local d = here[1] and PSS.Nav:DistanceTo(b.mapID, b.spawnPoints[1][1], b.spawnPoints[1][2], here)
      if not best or (d and (not bestD or d < bestD)) then best, bestD = b, d end
    end
  end
  return best, bestD
end

-- Pet log -----------------------------------------------------------------------
-- PetSkillScoutDB.petLog[guid] = { first, zone, npc, family, name, level, tamed }
local function PetGUID()
  local guid = UnitGUID and UnitGUID("pet")
  if type(guid) ~= "string" then return nil end
  local _, _, _, _, _, id = strsplit("-", guid)
  return guid, tonumber(id)
end

function C:ActiveLog()
  local guid = PetGUID()
  return guid and PetSkillScoutDB and PetSkillScoutDB.petLog and PetSkillScoutDB.petLog[guid], guid
end

-- Called after every pet scan.
function C:OnPet()
  if not PetSkillScoutDB then return end
  local pet = PSS.MyPet
  if not (pet and pet.active) then return end
  local guid, npc = PetGUID()
  if not guid then return end
  local log = Store("petLog")
  local rec = log[guid]
  if not rec then
    local tamed = PSS.RareTimer and PSS.RareTimer.lastTame and (GetTime and GetTime() or 0) - PSS.RareTimer.lastTame < 90
    rec = {first = Now(), zone = PSS.player and PSS.player.zone, npc = npc, tamed = tamed or nil}
    log[guid] = rec
  end
  rec.name, rec.family, rec.level = pet.name, pet.family, pet.level
  if pet.family then Store("familiesTamed")[pet.family] = true end
  local look = self:CollectNpc(npc, "pet")
  if look then
    PSS:Print(string.format(PSS:L("lookNew"), look.name, PSS:NameFamily(look.family)))
    if PSS.UI and PSS.UI.view == "collection" and PSS.UI.UpdateCollection then PSS.UI:UpdateCollection() end
  end
end

function C:DaysTogether(rec)
  if not (rec and rec.first) then return nil end
  return math.floor((Now() - rec.first) / 86400)
end

-- Stable pets and tamed rares count too.
function C:Sync()
  if not PetSkillScoutDB then return end
  for _, s in ipairs(PetSkillScoutDB.stablePets or {}) do
    if s.npcID then self:CollectNpc(s.npcID, "stable") end
    if s.family then Store("familiesTamed")[s.family] = true end
  end
  local R = PSS.RarePets
  if R then
    if not R.entries or #R.entries == 0 then R:Build() end
    for _, e in ipairs(R.entries) do
      if R:IsCollected(e) and e.beast.npcID then self:CollectNpc(e.beast.npcID, "rare") end
    end
  end
end

C.frame = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_STABLE_SHOW", "PET_STABLE_UPDATE"}) do
  pcall(C.frame.RegisterEvent, C.frame, e)
end
local delay = 0
C.frame:Hide()
C.frame:SetScript("OnUpdate", function(self, elapsed)
  delay = delay - (elapsed or 0)
  if delay > 0 then return end
  self:Hide()
  pcall(C.Sync, C)
  if PSS.MyPet and PSS.MyPet.active then pcall(C.OnPet, C) end
  if PSS.Achieve then pcall(PSS.Achieve.Check, PSS.Achieve) end
end)
C.frame:SetScript("OnEvent", function(self, event, unit)
  if event == "UNIT_PET" and unit ~= "player" then return end
  delay = 1.0 -- after MyPet's own rescan
  self:Show()
end)
C.frame.pssKey = "Collection"
PSS:Every(C.frame, 0.2)
