-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Realm showcase: which hunters on the realm have which pet look. With the
-- hello message every client also sends the looks it has collected (144 bits
-- in 24 characters) and the look of its active pet. Clicking an owner asks for
-- the card of their pet with that look. Can be switched off in Settings.
--   L~<24 chars>~<active look id>
local PSS = PetSkillScout
PSS.Showcase = {}
local W = PSS.Showcase
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, #ALPHA do VALUE[ALPHA:sub(i, i)] = i - 1 end
local KEEP = 7 * 86400

local function Now() return time and time() or 0 end
function W:Enabled() return not PetSkillScoutDB or PetSkillScoutDB.showcaseShare ~= false end

-- Bit order = SkinData.lua order, the same on every client.
local index
local function Index()
  if index then return index end
  index = {}
  for i, row in ipairs(PSS.SkinData or {}) do index[row[1]] = i end
  return index
end

function W:Encode(set)
  local n = #(PSS.SkinData or {})
  local out = {}
  for i = 1, n, 6 do
    local v = 0
    for b = 0, 5 do
      local row = PSS.SkinData[i + b]
      if row and set[row[1]] then v = v + 2 ^ b end
    end
    table.insert(out, ALPHA:sub(v + 1, v + 1))
  end
  return table.concat(out)
end

function W:Decode(text)
  local set = {}
  if type(text) ~= "string" then return set end
  for c = 1, #text do
    local v = VALUE[text:sub(c, c)]
    if v then
      for b = 0, 5 do
        if v % 2 == 1 then
          local row = PSS.SkinData[(c - 1) * 6 + b + 1]
          if row then set[row[1]] = true end
        end
        v = math.floor(v / 2)
      end
    end
  end
  return set
end

local function ActiveLook()
  local guid = UnitGUID and PSS.Plain(UnitGUID("pet"))
  if type(guid) ~= "string" or (PSS.IsSecret and PSS.IsSecret(guid)) then return 0 end
  local _, _, _, _, _, id = strsplit("-", guid)
  local C = PSS.Collection
  if not C then return 0 end
  C:Build()
  local look = C.byNpc[tonumber(id) or 0]
  return look and look.id or 0
end

function W:Message()
  local set = {}
  for id in pairs(PetSkillScoutDB and PetSkillScoutDB.looks or {}) do set[id] = true end
  return table.concat({"L", self:Encode(set), tostring(ActiveLook())}, PSS.Sync.SEP)
end

function W:Send()
  if not (self:Enabled() and PSS.Sync and PetSkillScoutDB) then return end
  PSS.Sync:SendAll(self:Message(), true)
end

local function OnLooks(parts, who)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.peerLooks = PetSkillScoutDB.peerLooks or {}
  local text = parts[2]
  if type(text) ~= "string" or #text > 40 or text:find("[^%w%+/]") then return end
  PetSkillScoutDB.peerLooks[who] = {t = Now(), bits = text, active = tonumber(parts[3]) or 0}
  W.cache = nil
  if PSS.UI and PSS.UI.view == "collection" and PSS.UI.UpdateCollection then PSS.UI:UpdateCollection(true) end
end

-- look id -> { {name, online, active}, ... } (decoded once per change)
function W:Owners(lookId)
  if not PetSkillScoutDB then return {} end
  if not self.cache then
    self.cache = {}
    local now = Now()
    for who, rec in pairs(PetSkillScoutDB.peerLooks or {}) do
      if rec.t and now - rec.t < KEEP then
        local online = PSS.Net and PetSkillScoutDB.peers and PetSkillScoutDB.peers[who] and
          now - (PetSkillScoutDB.peers[who].t or 0) < 1800
        for id in pairs(self:Decode(rec.bits)) do
          self.cache[id] = self.cache[id] or {}
          table.insert(self.cache[id], {name = who, online = online and true or false, active = rec.active == id})
        end
      else
        PetSkillScoutDB.peerLooks[who] = nil
      end
    end
    for _, list in pairs(self.cache) do
      table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.active ~= b.active then return a.active end
        return a.name < b.name
      end)
    end
  end
  return self.cache[lookId] or {}
end

-- Card for "R~#<look id>": the active pet or a stable pet with that look.
function W:CardForLook(lookId)
  local C, L = PSS.Collection, PSS.PetLink
  if not (C and L and self:Enabled()) then return nil end
  C:Build()
  if ActiveLook() == lookId then return L:OwnCard() end
  for _, s in ipairs(PetSkillScoutDB and PetSkillScoutDB.stablePets or {}) do
    local look = s.npcID and C.byNpc[tonumber(s.npcID)]
    if look and look.id == lookId then
      local skills = {}
      for _, sp in ipairs(s.spells or {}) do
        if sp.key and PSS.Abilities[sp.key] then table.insert(skills, {key = sp.key, rank = sp.rank}) end
      end
      local score, looks, rares = 0, 0, 0
      if PSS.Achieve then score, looks, rares = PSS.Achieve:Stats() end
      return {name = s.name, family = s.family, level = s.level, npc = s.npcID, display = s.displayID,
        skills = skills, looks = looks, rares = rares, score = score, hunter = UnitName and UnitName("player")}
    end
  end
end

-- Ask an owner for their card of this look.
function W:RequestCard(owner, lookId)
  local L = PSS.PetLink
  if not (L and L.Request) then return end
  local look = PSS.Collection and PSS.Collection.byId[lookId]
  L:Request(owner, "#" .. tostring(lookId), look and look.name or "?")
end

if PSS.Sync then PSS.Sync.handlers.L = OnLooks end
