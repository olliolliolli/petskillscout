-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Is a quest worth your time? Experience per minute and gear for any quest
-- of WoW Forever, from PSS.QuestDB (AllTheThings, MIT) plus what the game tells.
--   XP: exact from the client when known (quest dialog, quest log, turn-in),
--       otherwise an estimate from the quest's level (marked with "~").
--   Time: your own time for that quest when you did it before; otherwise an
--       estimate from its objectives, the walk from the quest giver to the
--       objective, dungeon / elite marks and, in the log, the counts to do.
--   Gear: the best reward compared with what you wear (PSS.GearCompare).
-- Verdict: "great" (purple), "ok", "skip" (grey: not worth the time).
local PSS = PetSkillScout
PSS.QuestWorth = {}
local W = PSS.QuestWorth

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end
local function DB() return PetSkillScoutDB or {} end
local function QL() return type(C_QuestLog) == "table" and C_QuestLog or nil end
local function Now() return Plain(Call(GetServerTime)) or (time and time()) or 0 end

-- Tuning ------------------------------------------------------------------
W.GREAT_RATIO = 1.4     -- XP per minute against a typical quest at your level
W.SKIP_RATIO = 0.8      -- below this the XP per minute is not worth the time
W.GEAR_GREAT = 10       -- attack power gain that makes any quest worth it
W.GEAR_OK = 3
W.TYPICAL_MIN = 11      -- minutes of a typical solo quest
W.WALK = 420            -- yards per minute on foot (7 yd/s)
W.MOUNT_LEVEL = 40
W.RIDE = 660            -- yards per minute mounted
W.DUNGEON_MIN = 35

-- Database record, with the giver position players confirmed in game
-- (QuestLearn) when it differs from the database (the giver stands elsewhere
-- or appears only after some condition). Cached per quest.
local learnedCache = {}
function W:Record(id)
  local r = PSS.QuestDB and PSS.QuestDB[id]
  -- Not in the database (or without a position) but offered by an NPC in game.
  local off = DB().questOffered and DB().questOffered[id]
  if off and off.m and off.x and not (r and r.m and r.x) then
    local c = {}
    for k, v in pairs(r or {}) do c[k] = v end
    c.m, c.x, c.y, c.g, c.learned = off.m, off.x, off.y, c.g or off.g, true
    return c
  end
  local QLm = PSS.QuestLearn
  local rec = QLm and QLm.Records and DB().questObs and QLm:Records()[id]
  if not (rec and QLm:Confirmed(rec)) then return r end
  local p = QLm:Best(rec)
  if not (p and p.m and p.x) then return r end
  if r and r.m == p.m and r.x and math.abs(r.x - p.x) <= 3 and math.abs(r.y - p.y) <= 3 then return r end
  local c = learnedCache[id]
  if c and c.m == p.m and c.x == p.x and c.y == p.y then return c end
  c = {}
  for k, v in pairs(r or {}) do c[k] = v end
  c.m, c.x, c.y, c.g, c.learned = p.m, p.x, p.y, rec.g or c.g, true
  c.n = c.n or rec.n
  learnedCache[id] = c
  return c
end
function W:NPCName(npc) return npc and PSS.QuestNPC and PSS.QuestNPC[npc] end

-- Player ------------------------------------------------------------------
function W:PlayerLevel()
  local v = Plain(Call(UnitLevel, "player"))
  if type(v) ~= "number" then v = PSS.player and PSS.player.level end
  return tonumber(v) or 1
end
function W:Side()
  local f = Plain(Call(UnitFactionGroup, "player"))
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end
function W:RaceID() return Plain(select(3, Call(UnitRace, "player"))) end
function W:ClassID() return Plain(select(3, Call(UnitClass, "player"))) end

-- Game state -----------------------------------------------------------------
-- Completed quests: the game's flag, plus our own list (DB().questDone),
-- filled from the server's full list at login, from every hand-in, and from
-- chains (a quest that needs X means X was done). Survives reinstalls of the
-- addon because the server list is read again at every login.
local function DoneSet()
  local d = PetSkillScoutDB
  if not d then return {} end
  d.questDone = d.questDone or {}
  return d.questDone
end
function W:MarkDone(id, depth)
  id = tonumber(id)
  if not id then return end
  local set = DoneSet()
  if set[id] then return end
  local rr = PSS.QuestDB and PSS.QuestDB[id]
  if rr and rr.r then return end -- repeatable: never "done for good"
  set[id] = true
  -- Previous quests of a done quest are done too (for all of them only when
  -- every one was required).
  depth = (depth or 0) + 1
  local r = PSS.QuestDB and PSS.QuestDB[id]
  if r and r.p and depth < 40 and (not r.pn or r.pn >= #r.p) then
    for _, p in ipairs(r.p) do self:MarkDone(p, depth) end
  end
end
function W:Done(id)
  if DoneSet()[id] then return true end
  local api = QL()
  local v
  if api and api.IsQuestFlaggedCompleted then v = Call(api.IsQuestFlaggedCompleted, id)
  elseif IsQuestFlaggedCompleted then v = Call(IsQuestFlaggedCompleted, id) end
  if Plain(v) == true then self:MarkDone(id); return true end
  return false
end
-- The server's list of every quest you completed (async on older clients).
function W:LoadCompleted()
  local n = 0
  local api = QL()
  if api and api.GetAllCompletedQuestIDs then
    for _, id in ipairs(Call(api.GetAllCompletedQuestIDs) or {}) do
      id = tonumber(Plain(id))
      if id then self:MarkDone(id); n = n + 1 end
    end
  end
  if n == 0 and type(GetQuestsCompleted) == "function" then
    local t = {}
    pcall(GetQuestsCompleted, t)
    for id, v in pairs(t) do if v then self:MarkDone(id); n = n + 1 end end
    if n == 0 and type(QueryQuestsCompleted) == "function" and not self.queried then
      self.queried = true
      pcall(QueryQuestsCompleted) -- answer: QUEST_QUERY_COMPLETE
    end
  end
  self.completedLoaded = n
  if n > 0 then
    self.byMap = nil
    if PSS.QuestPins and PSS.QuestPins.Refresh then PSS.QuestPins:Refresh() end
  end
  return n
end
function W:InLog(id)
  local api = QL()
  local idx
  if api and api.GetLogIndexForQuestID then idx = Plain(Call(api.GetLogIndexForQuestID, id))
  elseif GetQuestLogIndexByID then idx = Plain(Call(GetQuestLogIndexByID, id)) end
  return type(idx) == "number" and idx > 0
end
function W:Title(id)
  local api = QL()
  if api and api.GetTitleForQuestID then
    local t = Plain(Call(api.GetTitleForQuestID, id))
    if type(t) == "string" and t ~= "" then return t end
    if api.RequestLoadQuestByID then Call(api.RequestLoadQuestByID, id) end
  end
  local r = self:Record(id)
  return r and r.n and r.n:gsub("%s*%(%d+/%d+%)$", "") or ("#" .. id)
end

-- Can this character pick the quest up? (ignores reputation and professions,
-- which the database cannot check: those quests count as not available)
-- Returns ok, reason ("done" | "log" | "side" | "race" | "class" | "level" | "prev" | "other").
-- Quests the game offered at an NPC: remembered (with where you stood) so
-- the map shows them even if the database conditions disagree.
function W:Offered(id, npc)
  id = tonumber(id)
  if not (id and PetSkillScoutDB) then return end
  PetSkillScoutDB.questOffered = PetSkillScoutDB.questOffered or {}
  if PetSkillScoutDB.questOffered[id] then return end
  local rec = {t = time and time() or 0, g = npc}
  if PSS.Nav then
    local m, x, y = PSS.Nav:PlayerPos()
    if m and x then rec.m, rec.x, rec.y = m, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10 end
  end
  PetSkillScoutDB.questOffered[id] = rec
  self.byMap = nil
  if PSS.QuestPins and PSS.QuestPins.Refresh then PSS.QuestPins:Refresh() end
end

-- /pss questwhy: database quests near you and why each has no pin.
function W:Why(radius)
  radius = radius or 4
  local m, px, py
  if PSS.Nav then m, px, py = PSS.Nav:PlayerPos() end
  if not m then PSS:Print("questwhy: no position") return end
  px, py = px * 100, py * 100
  local level = self:PlayerLevel()
  local rows = {}
  for id, r in pairs(PSS.QuestDB or {}) do
    if r.m == m and r.x and math.abs(r.x - px) <= radius and math.abs(r.y - py) <= radius then
      local ok, why = self:Available(id, level)
      if ok then
        if not (r.g or r.ob) then why = "no giver"
        elseif r.hol and not (PSS.Holidays and PSS.Holidays:IsActive(r.hol)) then why = "holiday"
        elseif PSS.QuestPins and PSS.QuestPins:IsHiddenGiver(r.g, m, r.x, r.y) then why = "hidden by you"
        else why = "PIN" end
      end
      if why == "level" then why = "level " .. tostring(r.l) end
      if why == "prev" then why = "needs " .. table.concat(r.p or {}, ",") end
      if why ~= "done" and why ~= "log" then
        rows[#rows + 1] = string.format("%d %s (%.1f,%.1f): %s", id, tostring(r.n or "?"), r.x, r.y, why)
      end
    end
  end
  table.sort(rows)
  PSS:Print(string.format("questwhy: map %d at %.1f,%.1f, level %d, %d quests (done / in log not listed)", m, px, py, level, #rows))
  for _, line in ipairs(rows) do PSS:Print("  " .. line) end
end

-- Skill lines you have (professions, Cooking, Fishing, First Aid...), by ID.
local skillCache, skillAt = nil, -1e9
function W:Skills()
  local now = GetTime and GetTime() or 0
  if skillCache and now - skillAt < 10 then return skillCache end
  local out = {}
  if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
    local list = {Call(GetProfessions)}
    for i = 1, 6 do
      local idx = Plain(list[i])
      if idx then
        local _, _, rank, _, _, _, line = Call(GetProfessionInfo, idx)
        line = tonumber(Plain(line))
        if line then out[line] = tonumber(Plain(rank)) or 1 end
      end
    end
  end
  -- Classic-style clients: the character's skill list. Names are localised,
  -- so each skill line is matched by the name of its base spell.
  -- The character's skill list is always read too: GetProfessions can hold
  -- only the two main professions while Fishing / Cooking / First Aid (with
  -- their ranks) are only in this list. Lines already found keep their rank.
  if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
    local byName = {}
    local spellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for line, spell in pairs(W.SKILL_SPELLS) do
      local n = Plain(Call(spellName, spell))
      if type(n) == "string" then byName[n] = line end
    end
    for line, eng in pairs(W.SKILL_EN) do byName[eng] = byName[eng] or line end
    local n = tonumber(Plain(Call(GetNumSkillLines))) or 0
    for i = 1, n do
      local name, header, _, rank = Call(GetSkillLineInfo, i)
      name = Plain(name)
      if name and not Plain(header) and byName[name] and not out[byName[name]] then
        out[byName[name]] = tonumber(Plain(rank)) or 1
      end
    end
    out.listRead = n > 0 or nil
  end
  -- WoW Forever: skills may be missing from both lists, but the profession
  -- spells are in your spell book ("Fishing", "Cooking", "First Aid"...).
  -- Rank unknown there (0): the skill counts as learned.
  local book = PSS.SpellBar and PSS.SpellBar.Book and select(2, pcall(PSS.SpellBar.Book, PSS.SpellBar))
  if type(book) == "table" and next(book) then
    local spellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for line, spell in pairs(W.SKILL_SPELLS) do
      if out[line] == nil then
        local loc = Plain(Call(spellName, spell))
        if (loc and book[loc]) or book[W.SKILL_EN[line]] then out[line] = 0 end
      end
    end
    out.listRead = true
  end
  skillCache, skillAt = out, now
  return out
end
-- Skill level a quest needs, where known (single facts, e.g. Warcraft Wiki);
-- the database only says which skill. Other cases are learned at the NPC.
W.SKILL_MIN = {[2178] = 10}
-- Changes whenever a skill rank changes (re-check quests the NPC refused).
function W:SkillKey()
  local t = {}
  for line, rank in pairs(self:Skills()) do if type(line) == "number" then t[#t + 1] = line .. "=" .. tostring(rank) end end
  table.sort(t)
  return table.concat(t, ",")
end
-- Talking to an NPC: its database quests that look available but were not
-- offered are remembered as not available (for your level and skills).
function W:NotOffered(npc, offered)
  if not (npc and PetSkillScoutDB) then return end
  self:Index()
  local level, key = self:PlayerLevel(), self:SkillKey()
  local changed = false
  for _, id in ipairs(self.byGiver[npc] or {}) do
    if not offered[id] and not self:InLog(id) and not self:Done(id) then
      local ok = self:Available(id, level)
      if ok then
        PetSkillScoutDB.questNotOffered = PetSkillScoutDB.questNotOffered or {}
        PetSkillScoutDB.questNotOffered[id] = {lv = level, sk = key, t = time and time() or 0}
        changed = true
      end
    elseif offered[id] and PetSkillScoutDB.questNotOffered then
      PetSkillScoutDB.questNotOffered[id] = nil
    end
  end
  if changed and PSS.QuestPins and PSS.QuestPins.Refresh then PSS.QuestPins:Refresh() end
end

-- Base spell and English name of each skill line (for the classic skill list).
W.SKILL_SPELLS = {[185] = 2550, [356] = 7620, [129] = 3273, [182] = 2366, [186] = 2575, [393] = 8613,
  [165] = 2108, [164] = 2018, [197] = 3908, [202] = 4036, [171] = 2259, [333] = 7411}
W.SKILL_EN = {[185] = "Cooking", [356] = "Fishing", [129] = "First Aid", [182] = "Herbalism", [186] = "Mining",
  [393] = "Skinning", [165] = "Leatherworking", [164] = "Blacksmithing", [197] = "Tailoring",
  [202] = "Engineering", [171] = "Alchemy", [333] = "Enchanting"}
-- Unknown (no API at all): true, the quest is shown.
function W:HasSkill(line)
  local skills = self:Skills()
  local readable = type(GetProfessions) == "function" or skills.listRead
  if not readable then return true end
  return skills[tonumber(line) or 0] ~= nil
end
-- mr = {faction ID, reputation value}; unreadable reputation: only common
-- thresholds (up to friendly) are assumed to be met.
function W:HasRep(mr)
  local fac, need = tonumber(mr[1]), tonumber(mr[2]) or 0
  if not fac or fac == 0 then return true end
  local value
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local d = Call(C_Reputation.GetFactionDataByID, fac)
    if type(d) == "table" then value = tonumber(Plain(d.currentStanding)) end
  end
  if not value and type(GetFactionInfoByID) == "function" then
    local _, _, _, _, _, bar = Call(GetFactionInfoByID, fac)
    value = tonumber(Plain(bar))
  end
  if not value then return need <= 3000 end
  return value >= need
end

function W:Available(id, level)
  local r = self:Record(id)
  if not r then return false, "other" end
  if self:Done(id) then return false, "done" end
  if self:InLog(id) then return false, "log" end
  for _, a in ipairs(r.a or {}) do if self:Done(a) or self:InLog(a) then return false, "done" end end
  local side = self:Side()
  if r.s and side and r.s ~= side then return false, "side" end
  if r.rc then
    local race, ok = self:RaceID(), false
    for _, x in ipairs(r.rc) do if x == race then ok = true end end
    if race and not ok then return false, "race" end
  end
  if r.cl then
    local cls, ok = self:ClassID(), false
    for _, x in ipairs(r.cl) do if x == cls then ok = true end end
    if cls and not ok then return false, "class" end
  end
  -- The game offered this quest to you at an NPC (gossip / greeting window):
  -- whatever the database says about conditions, it is available.
  if DB().questOffered and DB().questOffered[id] then return true end
  -- You talked to its giver and the NPC did not offer it (skill level,
  -- hidden condition...): no pin until your level or skills change.
  local no = DB().questNotOffered and DB().questNotOffered[id]
  if no and no.lv == self:PlayerLevel() and no.sk == self:SkillKey() then return false, "npc" end
  local minSkill = W.SKILL_MIN[id]
  local rank = self:Skills()[r.sk or 0]
  if r.sk and minSkill and rank and rank > 0 and rank < minSkill then return false, "skill " .. minSkill end
  if r.sk and not self:HasSkill(r.sk) then return false, "skill" end
  if r.mr and not self:HasRep(r.mr) then return false, "rep" end
  if r.p then
    local need, have = r.pn or #r.p, 0
    for _, p in ipairs(r.p) do if self:Done(p) then have = have + 1 end end
    if have < need then return false, "prev" end
  end
  level = level or self:PlayerLevel()
  if r.l and level < r.l then return false, "level" end
  return true
end

-- Experience ---------------------------------------------------------------
-- Classic-style quest experience by quest level (fit through known values),
-- reduced for quests far below you.
function W:EstimateXP(qlevel, level)
  qlevel = math.max(1, qlevel)
  local xp = 12.1 * qlevel ^ 1.62
  local diff = (level or qlevel) - qlevel
  if diff >= 10 then xp = xp * 0.1
  elseif diff >= 6 then xp = xp * ({0.8, 0.6, 0.4, 0.2})[diff - 5] end
  return math.floor(xp / 5 + 0.5) * 5
end

function W:QuestLevel(id)
  local r = self:Record(id)
  local lv = PSS.QuestWorth.questLevels and PSS.QuestWorth.questLevels[id]
  if lv then return lv end
  if r and r.l then return r.l + 3 end
  return self:PlayerLevel()
end

function W:SaveXP(id, xp)
  xp = tonumber(Plain(xp))
  if not (id and xp and xp > 0 and PetSkillScoutDB) then return end
  PetSkillScoutDB.questXP = PetSkillScoutDB.questXP or {}
  PetSkillScoutDB.questXP[id] = math.floor(xp)
end

-- XP for this character; exact = true when the game reported it.
function W:XP(id, level)
  level = level or self:PlayerLevel()
  local saved = DB().questXP and DB().questXP[id]
  if saved then return saved, true end
  local fn = GetQuestLogRewardXP or (QL() and QL().GetQuestLogRewardXP)
  local v = tonumber(Plain(Call(fn, id)))
  if v and v > 0 then self:SaveXP(id, v); return math.floor(v), true end
  return self:EstimateXP(self:QuestLevel(id), level), false
end

-- Time --------------------------------------------------------------------------
local OBJ_MIN = {n = 5, i = 6, o = 3, x = 4}

function W:Travel(r, level)
  if not (r and r.ox and r.m and r.om == r.m and r.x) then return 0 end
  local w, h
  if PSS.Nav and PSS.Nav.MapSize then w, h = PSS.Nav:MapSize(r.m) end
  w, h = w or 1500, h or 1000
  local d = math.sqrt(((r.ox - r.x) / 100 * w) ^ 2 + ((r.oy - r.y) / 100 * h) ^ 2)
  local speed = (level or 1) >= self.MOUNT_LEVEL and self.RIDE or self.WALK
  return 2 * d / speed
end

-- Counts from the quest log (only for quests you have).
function W:LogObjectives(id)
  local api = QL()
  if not (api and api.GetQuestObjectives and self:InLog(id)) then return nil end
  local list = Call(api.GetQuestObjectives, id)
  if type(list) ~= "table" or #list == 0 then return nil end
  local minutes = 0
  for _, o in ipairs(list) do
    local need = tonumber(Plain(o.numRequired)) or 1
    local have = tonumber(Plain(o.numFulfilled)) or 0
    local left = math.max(0, need - have)
    local t = Plain(o.type)
    if t == "monster" then minutes = minutes + 0.6 * left
    elseif t == "item" then minutes = minutes + 0.9 * left
    elseif t == "object" then minutes = minutes + 0.7 * left
    else minutes = minutes + (o.finished and 0 or 3) end
  end
  return minutes
end

function W:Tag(id)
  local api = QL()
  if not (api and api.GetQuestTagInfo) then return nil end
  local info = Call(api.GetQuestTagInfo, id)
  local tag = type(info) == "table" and tonumber(Plain(info.tagID))
  if tag == 1 then return "elite" elseif tag == 81 then return "dungeon" elseif tag == 62 then return "raid" end
end

-- Your own times (minutes from accepting to turning in), median of the last 3.
function W:SavedMinutes(id)
  local t = DB().questTime and DB().questTime[id]
  if type(t) ~= "table" or #t == 0 then return nil end
  local s = {}
  for i, v in ipairs(t) do s[i] = v end
  table.sort(s)
  return s[math.ceil(#s / 2)]
end

-- Minutes; learned = true when it comes from your own play.
function W:Minutes(id, level)
  local saved = self:SavedMinutes(id)
  if saved then return math.max(1, saved), true end
  local r = self:Record(id) or {}
  level = level or self:PlayerLevel()
  if r.b and not r.o then return 3 + self:Travel(r, level), false end
  local m = 3
  local fromLog = self:LogObjectives(id)
  if fromLog then m = m + fromLog
  elseif r.o then for c in r.o:gmatch(".") do m = m + (OBJ_MIN[c] or 4) end
  else m = m + 2 end
  m = m + self:Travel(r, level)
  local tag = self:Tag(id)
  if r.d or tag == "dungeon" or tag == "raid" then m = m + self.DUNGEON_MIN
  elseif tag == "elite" then m = m + 10 end
  return math.floor(m + 0.5), false
end

-- Learning from play: accept / turn-in times and the experience you got.
function W:OnAccepted(id)
  if not (id and PetSkillScoutDB) then return end
  PetSkillScoutDB.questStart = PetSkillScoutDB.questStart or {}
  PetSkillScoutDB.questStart[id] = Now()
end
function W:OnTurnedIn(id, xp)
  if not (id and PetSkillScoutDB) then return end
  self:SaveXP(id, xp)
  local st = PetSkillScoutDB.questStart and PetSkillScoutDB.questStart[id]
  if st then
    PetSkillScoutDB.questStart[id] = nil
    local minutes = (Now() - st) / 60
    -- Long breaks (logged out, other quests on the way) say little: keep 0.3-90 min.
    if minutes >= 0.3 and minutes <= 90 then
      PetSkillScoutDB.questTime = PetSkillScoutDB.questTime or {}
      local t = PetSkillScoutDB.questTime[id] or {}
      t[#t + 1] = math.floor(minutes * 10 + 0.5) / 10
      while #t > 3 do table.remove(t, 1) end
      PetSkillScoutDB.questTime[id] = t
    end
  end
end

-- Gear -----------------------------------------------------------------------------
-- Best reward for you: gain in attack power and the item ID.
function W:Gear(id, level)
  local r = self:Record(id)
  if not (r and r.i and PSS.GearCompare) then return 0, nil end
  level = level or self:PlayerLevel()
  local best, bestId = 0, nil
  for _, item in ipairs(r.i) do
    local info = PSS.QuestItems and PSS.QuestItems[item]
    if not info or info.inv then
      local res = PSS.GearCompare:Compare("item:" .. item)
      if res and res.canUse ~= false and (res.reqLevel or 0) <= level + 2 and res.delta > best then
        best, bestId = res.delta, item
      elseif not res and PSS.Gear then PSS.Gear:Request(item) end
    end
  end
  return math.floor(best + 0.5), bestId
end

-- Verdict -------------------------------------------------------------------------
function W:Baseline(level)
  return self:EstimateXP(level + 2, level) / self.TYPICAL_MIN
end

-- Full rating: {verdict, xp, xpExact, minutes, minutesLearned, perMin, ratio, gear, gearItem, hunter}
function W:Rate(id, level)
  level = level or self:PlayerLevel()
  local xp, exact = self:XP(id, level)
  local minutes, learned = self:Minutes(id, level)
  local perMin = xp / math.max(1, minutes)
  local ratio = perMin / math.max(1, self:Baseline(level))
  local gear, gearItem = self:Gear(id, level)
  -- Chains of the hunter list (strong rewards) stay "great" until you outgrow them.
  local hunter = false
  local entry = PSS.Quests and PSS.Quests.ByQuest and PSS.Quests:ByQuest(id)
  if entry then
    local s = PSS.Quests:Status(entry, level)
    hunter = s ~= "outgrown" and s ~= "done"
  end
  local verdict
  if gear >= self.GEAR_GREAT or ratio >= self.GREAT_RATIO or (hunter and gear >= 0) then verdict = "great"
  elseif ratio < self.SKIP_RATIO and gear < self.GEAR_OK then verdict = "skip"
  else verdict = "ok" end
  if level >= self.CapLevel(self) and gear < self.GEAR_OK and not hunter then
    -- At the level cap experience means nothing: only rewards count.
    verdict = (gearItem and "ok") or "skip"
  end
  return {verdict = verdict, xp = xp, xpExact = exact, minutes = minutes, minutesLearned = learned,
    perMin = perMin, ratio = ratio, gear = gear, gearItem = gearItem, hunter = hunter}
end

function W:CapLevel()
  local m = Plain(Call(GetMaxPlayerLevel))
  return (type(m) == "number" and m >= 10) and m or 60
end

function W:Verdict(id, level) return self:Rate(id, level).verdict end

function W:Enabled() return DB().questWorth ~= false end

-- Short text: "~1,450 XP · ~9 min · 160 XP/min" (+ "+14 AP").
local function Thousands(n)
  local s = tostring(math.floor(n + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end
function W:Summary(rate)
  local L = function(k) return PSS:L(k) end
  local parts = {}
  parts[#parts + 1] = (rate.xpExact and "" or "~") .. Thousands(rate.xp) .. " XP"
  parts[#parts + 1] = (rate.minutesLearned and "" or "~") .. string.format(L("qwMin"), rate.minutes)
  parts[#parts + 1] = string.format(L("qwPerMin"), Thousands(rate.perMin))
  if rate.gear and rate.gear > 0 then parts[#parts + 1] = string.format(L("qwGear"), rate.gear) end
  return table.concat(parts, "  ·  ")
end

W.COLORS = {great = {0.74, 0.45, 1.0}, ok = {1.0, 0.82, 0.0}, skip = {0.55, 0.55, 0.55}}
W.HEX = {great = "|cffbd73ff", ok = "|cffffd100", skip = "|cff8c8c8c"}

-- Quests of the database by quest giver and by map (built once).
function W:Index()
  if self.byMap then return end
  self.byMap, self.byGiver = {}, {}
  local ids = {}
  for id in pairs(PSS.QuestDB or {}) do ids[id] = true end
  -- Quests learned in game (also ones the database does not have).
  local QLm = PSS.QuestLearn
  if QLm and QLm.Records and DB().questObs then for id in pairs(QLm:Records()) do ids[id] = true end end
  for id in pairs(DB().questOffered or {}) do ids[id] = true end
  for id in pairs(ids) do
    local r = self:Record(id) or {}
    if r.m and r.x then
      self.byMap[r.m] = self.byMap[r.m] or {}
      table.insert(self.byMap[r.m], id)
    end
    if r.g then
      self.byGiver[r.g] = self.byGiver[r.g] or {}
      table.insert(self.byGiver[r.g], id)
    end
  end
end

-- Available quests on a map with their ratings, best first.
-- Quests the game itself shows as available on a map (the "!" of the
-- modern map, C_QuestLine): quest ID -> {x, y} in 0-100. nil when the client
-- has no such API or reports nothing. Cached for 3 seconds per map.
local gameCache = {}
function W:GameAvailable(mapID)
  local QLn = C_QuestLine
  if not (mapID and QLn and QLn.GetAvailableQuestLines) then return nil end
  local now = GetTime and GetTime() or 0
  local c = gameCache[mapID]
  if c and now - c.t < 3 then return c.list end
  if QLn.RequestQuestLinesForMap then Call(QLn.RequestQuestLinesForMap, mapID) end
  local lines = Call(QLn.GetAvailableQuestLines, mapID)
  local list
  if type(lines) == "table" then
    for _, q in ipairs(lines) do
      local id, x, y = tonumber(Plain(q.questID)), tonumber(Plain(q.x)), tonumber(Plain(q.y))
      if id and x and y and not Plain(q.isHidden) then
        list = list or {}
        list[id] = {x = x * 100, y = y * 100, n = Plain(q.questName)}
        -- Quests the database lacks: kept for the next data update ("чек").
        if not (PSS.QuestDB and PSS.QuestDB[id]) and PetSkillScoutDB then
          PetSkillScoutDB.gameQuests = PetSkillScoutDB.gameQuests or {}
          PetSkillScoutDB.gameQuests[id] = {m = mapID, x = math.floor(x * 1000 + 0.5) / 10,
            y = math.floor(y * 1000 + 0.5) / 10, n = Plain(q.questName)}
        end
      end
    end
  end
  gameCache[mapID] = {t = now, list = list}
  return list
end

function W:OnMap(mapID, level)
  self:Index()
  level = level or self:PlayerLevel()
  local out = {}
  -- The game knows exactly which quests you can take and where their givers
  -- stand: when it reports them, its list is used (database quests the game
  -- does not offer - wrong phase, unmet condition - get no pin).
  local game = self:GameAvailable(mapID)
  if game then
    for id, gq in pairs(game) do
      local r = self:Record(id)
      local rec = {}
      for k, v in pairs(r or {}) do rec[k] = v end
      rec.x, rec.y, rec.m, rec.n = gq.x, gq.y, mapID, rec.n or gq.n
      out[#out + 1] = {id = id, r = rec, rate = self:Rate(id, level), game = true}
    end
  end
  if game then
    local order = {great = 1, ok = 2, skip = 3}
    table.sort(out, function(a, b)
      if a.rate.verdict ~= b.rate.verdict then return order[a.rate.verdict] < order[b.rate.verdict] end
      if a.rate.ratio ~= b.rate.ratio then return a.rate.ratio > b.rate.ratio end
      return a.id < b.id
    end)
    return out
  end
  for _, id in ipairs(self.byMap[mapID] or {}) do
    -- Map pins only for quests that an NPC gives: quests started by an item
    -- or object have no one standing at the position, holiday givers stand
    -- there only during the event (hol: shown while the calendar has it), and ATT entries
    -- marked for later expansions ("[CATA+]") do not exist in Forever.
    local rec = self:Record(id)
    local holidayOff = rec and rec.hol and not (PSS.Holidays and PSS.Holidays:IsActive(rec.hol))
    local pinnable = rec and (rec.g or rec.ob) and not holidayOff and not (rec.n and rec.n:find("%[%u+%+%]"))
    if pinnable and self:Available(id, level) then
      local rate = self:Rate(id, level)
      out[#out + 1] = {id = id, r = self:Record(id), rate = rate}
    end
  end
  local order = {great = 1, ok = 2, skip = 3}
  table.sort(out, function(a, b)
    if a.rate.verdict ~= b.rate.verdict then return order[a.rate.verdict] < order[b.rate.verdict] end
    if a.rate.ratio ~= b.rate.ratio then return a.rate.ratio > b.rate.ratio end
    return a.id < b.id
  end)
  return out
end

-- Best verdict of the available quests of an NPC (for nameplates).
function W:GiverVerdict(npc, level)
  self:Index()
  local best
  for _, id in ipairs(self.byGiver[npc] or {}) do
    local rec = self:Record(id)
    if not (rec and rec.hol and not (PSS.Holidays and PSS.Holidays:IsActive(rec.hol))) and self:Available(id, level) then
      local v = self:Verdict(id, level)
      if v == "great" then return "great" end
      if v == "ok" or not best then best = v end
    end
  end
  return best
end

-- Events: learn XP and times.
local ev = CreateFrame("Frame")
W.frame = ev
for _, name in ipairs({"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_DETAIL", "PLAYER_ENTERING_WORLD", "QUEST_QUERY_COMPLETE"}) do
  pcall(ev.RegisterEvent, ev, name)
end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "QUEST_ACCEPTED" then
    -- Modern clients pass the quest ID; older ones the log index first.
    local id = tonumber(Plain(a2)) or tonumber(Plain(a1))
    if a2 == nil then id = tonumber(Plain(a1)) end
    W:OnAccepted(id)
  elseif event == "QUEST_TURNED_IN" then
    W:OnTurnedIn(tonumber(Plain(a1)), a2)
    pcall(W.MarkDone, W, tonumber(Plain(a1)))
    if PSS.QuestPins and PSS.QuestPins.Refresh then PSS.QuestPins:Refresh() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not W.loadedOnce then
      W.loadedOnce = true
      if C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(W.LoadCompleted, W) end)
      else pcall(W.LoadCompleted, W) end
    end
  elseif event == "QUEST_QUERY_COMPLETE" then
    pcall(W.LoadCompleted, W)
  elseif event == "QUEST_DETAIL" then
    local id = tonumber(Plain(Call(GetQuestID)))
    if id then W:SaveXP(id, Call(GetRewardXP)) end
  end
end)
