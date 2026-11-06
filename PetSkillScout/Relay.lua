-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Relay between realms. The hunter network only reaches one realm, but the
-- addon's saved data belongs to the whole account: what a player learns on
-- one realm travels with them and is passed on when they play on another.
-- Nobody has to do anything: when a hunter asks the network what it knows
-- (at login, then every 30 minutes) everyone answers with a small batch,
-- the records sent the longest ago first, so over time all of it spreads.
--   quests        - QuestLearn ("O" records, answered there)
--   ammo vendors  - "V~npc~map~x~y~kinds~name" (same as a live find)
--   rare spots    - "X~npc~id~map~x~y~reports": where a rare was seen
-- Rare respawn timers are not relayed: they differ on every realm.
local PSS = PetSkillScout
PSS.Relay = {}
local RL = PSS.Relay

local SEP = "~"
local BATCH = 15          -- records of each kind per answer
local ANSWER_PAUSE = 300  -- seconds between our answers
local PULL_EVERY = 1800   -- ask the network again
local NEAR = 2            -- map percent: same spot
local MAX_SPOTS = 20      -- per rare

local function DB() return PetSkillScoutDB end
local function Now() return time and time() or 0 end
local function Clock() return GetTime and GetTime() or 0 end
local function Coord(v) local n = tonumber(v); if n and n >= 0 and n <= 100 then return n end end

function RL:Enabled()
  local d = DB()
  return d and d.netEnabled ~= false and d.relay ~= false
end

RL.stats = {sent = 0, got = 0}

-- Rare spots -------------------------------------------------------------------
function RL:Spots()
  local d = DB()
  d.rareSpots = d.rareSpots or {}
  return d.rareSpots
end

-- Adds a point to a rare; returns true when it is new.
function RL:AddSpot(id, npc, m, x, y, n, who)
  if not (id and m and x and y) then return false end
  local list = self:Spots()[id] or {}
  self:Spots()[id] = list
  list.npc = list.npc or npc
  for _, p in ipairs(list) do
    if p.m == m and math.abs(p.x - x) <= NEAR and math.abs(p.y - y) <= NEAR then
      p.n = math.max(p.n or 1, n or 1)
      if who and who ~= p.by then p.c = true end -- seen by two players: confirmed
      return false
    end
  end
  if #list >= MAX_SPOTS then table.remove(list, 1) end
  list[#list + 1] = {m = m, x = x, y = y, n = n or 1, t = Now(), by = who}
  return true
end

-- Own and network sightings that are not in the relay list yet.
function RL:Collect()
  local d = DB()
  for _, src in ipairs({d.rareSeen or {}, d.rareShared or {}}) do
    for id, rec in pairs(src) do
      if type(rec) == "table" then
        self:AddSpot(id, nil, tonumber(rec.mapID), Coord(rec.x), Coord(rec.y), 1, rec.who)
      end
    end
  end
end

-- Answering ----------------------------------------------------------------------
local sentAt = {}   -- key -> clock of our last send (this session)
local lastAnswer = -1e9

local function Oldest(keys)
  table.sort(keys, function(a, b)
    local sa, sb = sentAt[a.k] or -1, sentAt[b.k] or -1
    if sa ~= sb then return sa < sb end
    return a.k < b.k
  end)
end

function RL:Answer(force)
  if not self:Enabled() then return 0 end
  local S = PSS.Sync
  if not (S and S.SendAll) then return 0 end
  local now = Clock()
  if not force and now - lastAnswer < ANSWER_PAUSE then return 0 end
  lastAnswer = now
  pcall(self.Collect, self)
  local msgs = {}
  -- Ammo vendors.
  local vend = {}
  for npc, rec in pairs(DB().ammoVendors or {}) do
    if rec.m and rec.x and rec.y then vend[#vend + 1] = {k = "v" .. tostring(npc), npc = npc, rec = rec} end
  end
  Oldest(vend)
  for i = 1, math.min(BATCH, #vend) do
    local v = vend[i]
    local name = tostring(v.rec.n or "?"):gsub(SEP, ""):sub(1, 40)
    msgs[#msgs + 1] = {v.k, table.concat({"V", tostring(v.npc), tostring(v.rec.m), string.format("%.1f", v.rec.x),
      string.format("%.1f", v.rec.y), v.rec.k or "", name}, SEP)}
  end
  -- Rare spots.
  local spots = {}
  for id, list in pairs(self:Spots()) do
    for i, p in ipairs(list) do
      spots[#spots + 1] = {k = "x" .. tostring(id) .. ":" .. i, id = id, npc = list.npc, p = p}
    end
  end
  Oldest(spots)
  for i = 1, math.min(BATCH, #spots) do
    local s = spots[i]
    msgs[#msgs + 1] = {s.k, table.concat({"X", tostring(s.npc or 0), tostring(s.id), tostring(s.p.m),
      string.format("%.1f", s.p.x), string.format("%.1f", s.p.y), tostring(s.p.n or 1)}, SEP)}
  end
  if #msgs == 0 then return 0 end
  local function send()
    for _, m in ipairs(msgs) do
      if #m[2] <= 250 then
        sentAt[m[1]] = Clock()
        S:SendAll(m[2], true)
        self.stats.sent = self.stats.sent + 1
      end
    end
  end
  -- Not everyone answers at the same moment.
  if C_Timer and C_Timer.After and not force then C_Timer.After(3 + math.random() * 7, send) else send() end
  return #msgs
end

-- Receiving -------------------------------------------------------------------------
local function OnSpot(parts, who)
  if not RL:Enabled() then return end
  local _, npc, id, m, x, y, n = unpack(parts)
  m, x, y = tonumber(m), Coord(x), Coord(y)
  if not (id and id ~= "" and #id <= 40 and m and m >= 1 and m <= 100000 and x and y) then return end
  -- Only rares the addon knows: nothing else may fill the saved data.
  local R = PSS.RarePets
  if R and R.entries and #R.entries > 0 then
    local known = false
    for _, e in ipairs(R.entries) do if tostring(e.id) == id then known = true break end end
    if not known then return end
  end
  if RL:AddSpot(id, tonumber(npc), m, x, y, tonumber(n), who) then RL.stats.got = RL.stats.got + 1 end
end

if PSS.Sync then
  PSS.Sync.handlers.X = OnSpot
  -- "P" (what do you know?) is answered by QuestLearn for quests; answer the rest too.
  local prev = PSS.Sync.handlers.P
  PSS.Sync.handlers.P = function(...)
    if prev then pcall(prev, ...) end
    pcall(RL.Answer, RL)
  end
end

-- Built-in learned data (tools/learned.lua at each data update): merged into
-- your saved data once per version, so it is used and relayed like your own.
function RL:Seed()
  local L, d = PSS.LearnedData, DB()
  if not (L and d) or d.learnedSeed == PSS.version then return 0 end
  local n = 0
  local QL = PSS.QuestLearn
  for id, r in pairs(L.quests or {}) do
    if QL and not QL:Records()[id] then
      local rec = QL:Add(id, {n = r.n, g = r.g, gn = r.gn, f = r.f, m = r.m, x = r.x, y = r.y, i = r.i}, "~data")
      if rec then rec.b = true; n = n + 1 end
    end
  end
  d.ammoVendors = d.ammoVendors or {}
  for npc, v in pairs(L.vendors or {}) do
    if not d.ammoVendors[npc] then
      d.ammoVendors[npc] = {n = v.n, m = v.m, x = v.x, y = v.y, k = v.k, z = v.z, from = "data", t = 0}
      n = n + 1
    end
  end
  for id, list in pairs(L.rares or {}) do
    for _, p in ipairs(list) do
      if self:AddSpot(id, list.npc, p.m, p.x, p.y, 1, "~data") then n = n + 1 end
      for _, q in ipairs(self:Spots()[id]) do
        if q.m == p.m and math.abs(q.x - p.x) <= NEAR and math.abs(q.y - p.y) <= NEAR then q.c = true end
      end
    end
  end
  d.learnedSeed = PSS.version
  return n
end
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function() pcall(RL.Seed, RL) end)
end

-- Ask again now and then: other hunters may have come from other realms.
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(PULL_EVERY, function()
    local QL = PSS.QuestLearn
    if QL and RL:Enabled() then QL.pulled = nil; pcall(QL.Pull, QL) end
  end)
end
