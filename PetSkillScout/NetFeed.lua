-- Live feed of the hunter network (Network tab): who is online and what
-- they share right now. Built from the hidden addon messages that arrive
-- anyway (Sync.lua); nothing extra is sent. Events are kept for this session
-- (the newest 300); counters of what you sent and received are saved.
local PSS = PetSkillScout
PSS.NetFeed = {events = {}}
local F = PSS.NetFeed

local MAX = 300
local function Now() return time and time() or 0 end
local function DB() return PetSkillScoutDB end

-- kind: quest / rare / tame / kill / vendor / queue / join
F.GROUP = {quest = "quest", rare = "rare", tame = "rare", kill = "rare", queue = "rare", vendor = "other", join = "hunter"}

function F:Stats()
  local d = DB()
  if not d then return {sent = 0, recv = 0} end
  d.netStats = d.netStats or {sent = 0, recv = 0}
  return d.netStats
end

function F:Add(kind, who, a, b, mine)
  local list = self.events
  table.insert(list, 1, {t = Now(), kind = kind, who = who, a = a, b = b, mine = mine})
  if #list > MAX then list[#list] = nil end
  self.changed = true
  if PSS.NetChat then pcall(PSS.NetChat.Post, PSS.NetChat, list[1]) end
  if PSS.UI and PSS.UI.view == "network" and PSS.UI.UpdateNetwork then pcall(PSS.UI.UpdateNetwork, PSS.UI) end
end

local function RareName(npc, id)
  local find = PSS.Sync and PSS.Sync.FindEntry
  local e = find and find(tonumber(npc), id)
  return e and e.name, e and e.zone
end

local joined = {}
-- Every message that passed the checks in Sync:Receive.
function F:OnMessage(parts, who)
  local kind = parts[1]
  local st = self:Stats()
  if kind ~= "P" then st.recv = (st.recv or 0) + 1 end
  if kind == "H" then
    if not joined[who] then joined[who] = true; self:Add("join", who, parts[2]) end
  elseif kind == "S" then
    local name, zone = RareName(parts[2], parts[3])
    if name then self:Add("rare", who, name, zone) end
  elseif kind == "K" then
    local name = RareName(parts[2], parts[3])
    if name then self:Add(parts[5] == "tame" and "tame" or "kill", who, name) end
  elseif kind == "V" then
    self:Add("vendor", who, parts[7])
  elseif kind == "O" then
    self:Add("quest", who, parts[9], parts[3] ~= "" and parts[3] or nil)
  elseif kind == "Q" and (parts[3] == "j") then
    local name = RareName(nil, parts[2])
    if name then self:Add("queue", who, name) end
  end
end

-- What this player sent (Sync:SendAll); quest records show in the feed too.
function F:OnSent(msg)
  local kind = msg:match("^(%a)")
  if kind == "P" or kind == "H" then return end
  local st = self:Stats()
  st.sent = (st.sent or 0) + 1
  if kind == "O" then
    local parts = {strsplit(PSS.Sync.SEP, msg)}
    self:Add("quest", UnitName and UnitName("player") or "?", parts[9], parts[3] ~= "" and parts[3] or nil, true)
  end
end

-- Hunters seen on the network in the last 30 minutes, newest first.
function F:Online()
  local out, now = {}, Now()
  for name, p in pairs((DB() and DB().peers) or {}) do
    if p.t and now - p.t < 1800 then
      out[#out + 1] = {name = name, t = p.t, v = p.v, score = p.score or 0, g = p.g, guild = p.guild}
    end
  end
  table.sort(out, function(x, y) if x.t ~= y.t then return x.t > y.t end return x.name < y.name end)
  return out
end

-- Events for a filter: all / quest / rare / hunter / other; mine = include own.
function F:List(filter, mine)
  local out = {}
  for _, e in ipairs(self.events) do
    if (filter == "all" or self.GROUP[e.kind] == filter) and (mine or not e.mine) then out[#out + 1] = e end
  end
  return out
end

-- Learned quests summary for the contribution block.
function F:QuestCounts()
  local L = PSS.QuestLearn
  local n, ok, mine = 0, 0, 0
  if L then
    for _, rec in pairs(L:Records()) do
      n = n + 1
      if L:Confirmed(rec) then ok = ok + 1 end
      if rec.me then mine = mine + 1 end
    end
  end
  return n, ok, mine
end
