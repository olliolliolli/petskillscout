-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Quest givers and rewards learned in game (Settings > Quests, on by default).
-- When you open a quest at an NPC, quests the AllTheThings database does not
-- know (or knows without a quest giver position or with other rewards) are
-- recorded: quest ID, title, quest giver NPC, map and position (where you
-- stand, next to the NPC), faction and reward items. Records are shared over
-- the hunter network and merged; a position counts as confirmed when two
-- players reported the same spot, or when you saw it yourself.
--   O~quest~npc~map~x~y~faction~items~title   one record (x, y in 0-100)
--   P                                          "send me what you have" (login)
-- Only quest data is sent. Nothing is written to visible chat.
local PSS = PetSkillScout
PSS.QuestLearn = {}
local QL = PSS.QuestLearn

local SEP = "~"
local NEAR = 3          -- map percent: two reports this close are the same spot
local MAX_RECORDS = 3000
local MAX_REPORTERS = 8
local SHARE_BATCH = 15  -- records sent per answer to a "P"
local PULL_PAUSE = 300  -- seconds between answers to "P"

local function DB() return PetSkillScoutDB end
local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return Plain(a), Plain(b), Plain(c) end
end
local function Now() return time and time() or 0 end
local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

function QL:Enabled() local d = DB(); return not d or d.questLearn ~= false end
function QL:Records()
  local d = DB()
  if not d then return {} end
  d.questObs = d.questObs or {}
  return d.questObs
end

local function Me() return (UnitName and Plain(UnitName("player"))) or "me" end
local function Faction()
  local f = PSS.player and PSS.player.faction
  if not f and UnitFactionGroup then f = Plain(UnitFactionGroup("player")) end
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

-- NPC ID from a creature GUID ("Creature-0-...-npcID-spawn").
local function NpcID(unit)
  local guid = UnitGUID and Plain(UnitGUID(unit))
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" then return tonumber(id) end
end

-- Is this quest worth learning: unknown to the database, no giver position
-- there, or rewards the database does not list.
function QL:Wanted(id, items)
  local r = PSS.QuestDB and PSS.QuestDB[id]
  if not (r and r.m and r.x) then return true end
  local known = {}
  for _, i in ipairs(r.i or {}) do known[i] = true end
  for _, i in ipairs(items or {}) do if not known[i] then return true end end
  return false
end

local function Distance(a, b)
  if not (a and b) or a.m ~= b.m then return math.huge end
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

-- Best position of a record: the spot most reporters agree on.
-- Returns point, number of reporters there, seen by me.
function QL:Best(rec)
  local best, bestN, mine
  for who, p in pairs(rec.r or {}) do
    local n = 0
    for _, q in pairs(rec.r) do if Distance(p, q) <= NEAR then n = n + 1 end end
    local isMe = who == Me()
    if not best or n > bestN or (n == bestN and isMe) then best, bestN, mine = p, n, isMe end
  end
  if best and not mine then
    local myPoint = rec.r[Me()]
    if myPoint and Distance(myPoint, best) <= NEAR then mine = true end
  end
  return best, bestN or 0, mine or false
end

function QL:Confirmed(rec)
  local p, n, mine = self:Best(rec)
  return p ~= nil and (n >= 2 or mine)
end

local function Prune(recs)
  local n, oldest, oldestID = 0, nil, nil
  for id, r in pairs(recs) do
    n = n + 1
    if not oldest or (r.t or 0) < oldest then oldest, oldestID = r.t or 0, id end
  end
  if n > MAX_RECORDS and oldestID then recs[oldestID] = nil end
end

-- Merge one report (own or from the network). Returns the record.
function QL:Add(id, data, who)
  id = tonumber(id)
  if not id or id <= 0 or not DB() then return end
  local recs = self:Records()
  local rec = recs[id]
  if not rec then
    rec = {r = {}, i = {}}
    recs[id] = rec
    Prune(recs)
  end
  if data.n and data.n ~= "" then rec.n = tostring(data.n):sub(1, 80) end
  if data.g then rec.g = data.g end
  if data.gn and data.gn ~= "" then rec.gn = tostring(data.gn):sub(1, 40) end
  if data.f then rec.f = data.f end
  if data.m and data.x and data.y then
    local reporters = 0
    for _ in pairs(rec.r) do reporters = reporters + 1 end
    if rec.r[who] or reporters < MAX_REPORTERS then
      rec.r[who] = {m = data.m, x = Round(data.x), y = Round(data.y)}
    end
  end
  local have = {}
  for _, i in ipairs(rec.i) do have[i] = true end
  for _, i in ipairs(data.i or {}) do
    if not have[i] and #rec.i < 12 then rec.i[#rec.i + 1] = i; have[i] = true end
  end
  rec.t = Now()
  if who == Me() then rec.me = true end
  self.changed = true
  return rec
end

-- Reward items in the open quest window (choices and fixed rewards).
local function RewardItems()
  local out, seen = {}, {}
  local function add(kind, n)
    for i = 1, tonumber(n) or 0 do
      local link = Call(GetQuestItemLink, kind, i)
      local item = type(link) == "string" and tonumber(link:match("item:(%d+)"))
      if item and not seen[item] then out[#out + 1] = item; seen[item] = true end
    end
  end
  add("choice", Call(GetNumQuestChoices))
  add("reward", Call(GetNumQuestRewards))
  return out
end

function QL:Message(id, rec)
  local p = self:Best(rec) or {}
  local items = table.concat(rec.i or {}, ",")
  local title = tostring(rec.n or ""):gsub(SEP, " ")
  local msg = table.concat({"O", id, rec.g or "", p.m or "", p.x or "", p.y or "", rec.f or "", items, title}, SEP)
  if #msg > 250 then msg = msg:sub(1, 250) end
  return msg
end

local function Share(id, rec)
  local S = PSS.Sync
  if not (S and S.Enabled and S.Enabled() and S.SendAll) then return end
  S:SendAll(QL:Message(id, rec), true)
end

-- Quest window at an NPC: record what the database lacks.
function QL:OnDetail()
  if not self:Enabled() then return end
  local id = tonumber(Call(GetQuestID))
  if not id or id <= 0 then return end
  local items = RewardItems()
  if not self:Wanted(id, items) then return end
  local data = {n = Call(GetTitleText), i = items, f = Faction()}
  local npc = NpcID("npc")
  if npc then
    data.g, data.gn = npc, Call(UnitName, "npc")
    local mapID, x, y
    if PSS.Nav then mapID, x, y = PSS.Nav:PlayerPos() end
    if mapID and x and y then data.m, data.x, data.y = mapID, x * 100, y * 100 end
  end
  local rec = self:Add(id, data, Me())
  if rec then Share(id, rec) end
  return rec
end

-- Turn-in window: rewards only (the NPC here is who ends the quest).
function QL:OnComplete()
  if not self:Enabled() then return end
  local id = tonumber(Call(GetQuestID))
  if not id or id <= 0 then return end
  local items = RewardItems()
  if #items == 0 or not self:Wanted(id, items) then return end
  local rec = self:Add(id, {n = Call(GetTitleText), i = items, f = Faction()}, Me())
  if rec then Share(id, rec) end
end

-- Network ----------------------------------------------------------------------
local function Num(v) return tonumber(v) end
local function Coord(v)
  local n = tonumber(v)
  if n and n >= 0 and n <= 100 then return n end
end

local function OnRecord(parts, who)
  if not QL:Enabled() then return end
  local _, id, npc, map, x, y, fac, items, title = unpack(parts)
  id = Num(id)
  if not id then return end
  local data = {g = Num(npc), m = Num(map), x = Coord(x), y = Coord(y), n = title}
  if fac == "A" or fac == "H" then data.f = fac end
  data.i = {}
  for item in tostring(items or ""):gmatch("%d+") do
    if #data.i < 12 then data.i[#data.i + 1] = tonumber(item) end
  end
  if not (data.m and data.x and data.y) then data.m, data.x, data.y = nil, nil, nil end
  QL:Add(id, data, who)
end

local lastAnswer = -1e9
local sentAt = {}
local function OnPull()
  if not QL:Enabled() then return end
  local now = GetTime and GetTime() or 0
  if now - lastAnswer < PULL_PAUSE then return end
  lastAnswer = now
  local list = {}
  for id, rec in pairs(QL:Records()) do
    if (rec.me or QL:Confirmed(rec)) and (not sentAt[id] or now - sentAt[id] > 1800) then
      list[#list + 1] = {id = id, t = rec.t or 0}
    end
  end
  table.sort(list, function(a, b) return a.t > b.t end)
  local delay = 2 + math.random() * 6  -- not everyone answers at once
  local function send()
    for i = 1, math.min(SHARE_BATCH, #list) do
      local id = list[i].id
      sentAt[id] = now
      Share(id, QL:Records()[id])
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay, send) else send() end
end

function QL:Pull()
  local S = PSS.Sync
  if self.pulled or not (S and S.Enabled and S.Enabled() and S.SendAll) then return end
  if S:SendAll("P", true) then self.pulled = true end
end

if PSS.Sync then
  PSS.Sync.handlers.O = OnRecord
  PSS.Sync.handlers.P = OnPull
end

-- Lookup for other modules ---------------------------------------------------------
-- Learned quest by title (chain suffix ignored), your faction preferred.
-- Returns id, record {n, g, gn, m, x, y, f, i, confirmed, reporters}.
function QL:ByTitle(title)
  if type(title) ~= "string" then return nil end
  local want = title:gsub("%s*%(%d+/%d+%)$", ""):lower()
  local fac = Faction()
  local bestID, best, bestScore
  for id, rec in pairs(self:Records()) do
    if rec.n and rec.n:gsub("%s*%(%d+/%d+%)$", ""):lower() == want and not (rec.f and fac and rec.f ~= fac) then
      local p, n, mine = self:Best(rec)
      local confirmed = p ~= nil and (n >= 2 or mine)
      local score = (p and 2 or 0) + (confirmed and 1 or 0)
      if not bestScore or score > bestScore then
        bestScore, bestID = score, id
        best = {n = rec.n, g = rec.g, gn = rec.gn, f = rec.f, i = rec.i, confirmed = confirmed, reporters = n,
          m = p and p.m, x = p and p.x, y = p and p.y, learned = true}
      end
    end
  end
  return bestID, best
end

-- Events -----------------------------------------------------------------------------
local ev = CreateFrame("Frame")
QL._frame = ev
ev:RegisterEvent("QUEST_DETAIL")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
  if event == "QUEST_DETAIL" then pcall(QL.OnDetail, QL)
  elseif event == "QUEST_COMPLETE" then pcall(QL.OnComplete, QL)
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Ask the network once per session, after the channel had time to join.
    if C_Timer and C_Timer.After then C_Timer.After(20, function() pcall(QL.Pull, QL) end) end
  end
end)
