-- Hunter quests (Quests tab): which useful quest chains this character can
-- do now, which are done, and a reminder when a new one becomes available.
-- Data: PSS.QuestData. Everything about progress is read from the game:
-- completed quests, quests in the log and reward items you own.
-- The addon only shows information; it never accepts or turns in quests.
local PSS = PetSkillScout
PSS.Quests = {}
local Q = PSS.Quests

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end
local function L(k) return PSS:L(k) end
local function DB() return PetSkillScoutDB or {} end
local function QL() return type(C_QuestLog) == "table" and C_QuestLog or nil end

Q.SOON = 3          -- "in N levels" counts as soon up to this many levels
Q.REMIND_SPAN = 8   -- no reminders for chains far below your level (unless an upgrade)

-- Player ------------------------------------------------------------------
function Q:IsHunter()
  local _, cls = Call(UnitClass, "player")
  cls = Plain(cls)
  return cls == nil or cls == "HUNTER"
end

function Q:Side()
  local f = Plain(Call(UnitFactionGroup, "player")) or (PSS.player and PSS.player.faction)
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

function Q:Level()
  local v = Plain(Call(UnitLevel, "player"))
  if type(v) ~= "number" then v = PSS.player and PSS.player.level end
  return tonumber(v) or 1
end

-- Entries for this character's faction, in level order.
function Q:List()
  local side, out = self:Side(), {}
  for _, e in ipairs(PSS.QuestData or {}) do
    local s = self:Info(e).side
    if not (s and side and s ~= side) then out[#out + 1] = e end
  end
  table.sort(out, function(a, b)
    local la, lb = self:MinLevel(a), self:MinLevel(b)
    if la ~= lb then return la < lb end
    return a.key < b.key
  end)
  return out
end

-- The quest of the chain for your faction (chains with an Alliance and a Horde version).
function Q:Primary(e)
  local side = self:Side()
  local list = e.final or {e.quests and e.quests[#e.quests]}
  local DBq = PSS.QuestDB or {}
  for _, id in ipairs(list) do
    local r = DBq[id]
    if r and (not r.s or not side or r.s == side) then return id, r end
  end
  local id = list[1]
  return id, id and DBq[id]
end

-- Giver, zone, position, level and faction: QuestDB first, then the fallbacks.
-- x, y are map percent (0-100) like every other position in the addon.
function Q:Info(e)
  local id, r = self:Primary(e)
  local side = self:Side()
  local alt = e.bySide and side and e.bySide[side]
  local info = {quest = id, side = (r and r.s) or e.side, lvl = (r and r.l) or e.lvl}
  if r and r.m and r.x then
    info.mapID, info.x, info.y = r.m, r.x, r.y
  elseif alt then
    info.x, info.y = alt.x, alt.y
  end
  info.npc = (r and r.g and PSS.QuestNPC and PSS.QuestNPC[r.g]) or (alt and alt.npc) or e.npc
  info.zone = (alt and not (r and r.m) and alt.zone) or e.zone
  return info
end

function Q:MinLevel(e) return self:Info(e).lvl or e.lvl or 1 end

-- Hunter entry that contains a quest ID (for the general quest ratings).
function Q:ByQuest(id)
  if not self.byQuest then
    self.byQuest = {}
    for _, e in ipairs(PSS.QuestData or {}) do
      for _, q in ipairs(e.quests or {}) do self.byQuest[q] = e end
      for _, q in ipairs(e.final or {}) do self.byQuest[q] = e end
    end
  end
  return self.byQuest[id]
end

function Q:Get(key)
  for _, e in ipairs(PSS.QuestData or {}) do if e.key == key then return e end end
end

-- Game state ---------------------------------------------------------------
function Q:Finals(e)
  if e.final then return e.final end
  local list = {}
  if e.quests and #e.quests > 0 then list[1] = e.quests[#e.quests] end
  local learned = DB().questLearned and DB().questLearned[e.key]
  if learned then list[#list + 1] = learned end
  return list
end

function Q:QuestDone(id)
  local api = QL()
  local v
  if api and api.IsQuestFlaggedCompleted then v = Call(api.IsQuestFlaggedCompleted, id)
  elseif IsQuestFlaggedCompleted then v = Call(IsQuestFlaggedCompleted, id) end
  return Plain(v) == true
end

function Q:InLogQuest(id)
  local api = QL()
  if api and api.GetLogIndexForQuestID then
    local idx = Plain(Call(api.GetLogIndexForQuestID, id))
    return type(idx) == "number" and idx > 0
  end
  if GetQuestLogIndexByID then
    local idx = Plain(Call(GetQuestLogIndexByID, id))
    return type(idx) == "number" and idx > 0
  end
  return false
end

function Q:Owned(id)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  local n = Plain(Call(fn, id, true))
  return type(n) == "number" and n > 0
end

function Q:IsDone(e)
  for _, id in ipairs(self:Finals(e)) do if self:QuestDone(id) then return true end end
  for _, id in ipairs(e.items or {}) do if self:Owned(id) then return true end end
  return false
end

function Q:InLog(e)
  for _, id in ipairs(e.quests or {}) do if self:InLogQuest(id) then return true end end
  for _, id in ipairs(self:Finals(e)) do if self:InLogQuest(id) then return true end end
  return false
end

-- Names ----------------------------------------------------------------------
-- Localized quest title from the client (nil until it is cached).
function Q:QuestTitle(id)
  local api = QL()
  if not (api and api.GetTitleForQuestID) then return nil end
  local t = Plain(Call(api.GetTitleForQuestID, id))
  if type(t) == "string" and t ~= "" then return t end
  if api.RequestLoadQuestByID then Call(api.RequestLoadQuestByID, id) end
end

function Q:Title(e)
  local id = self:Primary(e) or self:Finals(e)[1]
  return (id and self:QuestTitle(id)) or e.name
end

function Q:ItemName(e, id)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local name, link, quality = Call(fn, id)
  name, link, quality = Plain(name), Plain(link), Plain(quality)
  if type(name) ~= "string" then
    if PSS.Gear then PSS.Gear:Request(id) end
    local qi = PSS.QuestItems and PSS.QuestItems[id]
    name = (e.inames and e.inames[id]) or (qi and qi.n) or ("item " .. id)
    quality = quality or (qi and qi.q)
  end
  return name, (type(link) == "string" and link or nil), (type(quality) == "number" and quality or nil)
end

function Q:ItemIcon(id)
  if PSS.Gear and PSS.Gear.Icon then return PSS.Gear:Icon(id) end
  local fn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  return Plain(Call(fn, id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Zone: localized name and uiMapID when known.
function Q:ZoneMapID(e)
  local info = self:Info(e)
  if info.mapID then return info.mapID end
  return (PSS.QuestZoneMaps and PSS.QuestZoneMaps[info.zone]) or PSS:ZoneMapID(info.zone)
end

function Q:ZoneName(e)
  local id = self:ZoneMapID(e)
  if id and C_Map and C_Map.GetMapInfo then
    local info = Call(C_Map.GetMapInfo, id)
    local name = info and Plain(info.name)
    if type(name) == "string" and name ~= "" then return name end
  end
  return self:Info(e).zone or e.zone
end

-- Value of the reward for you ------------------------------------------------
-- Best reward choice compared with your ranged weapon, in attack power.
-- Returns gain, best item ID, known (false while item stats are not cached).
function Q:Gain(e, spec)
  if e.kind ~= "ranged" or not PSS.Gear then return nil, e.items and e.items[1], false end
  local G = PSS.Gear
  spec = spec or G:Spec()
  local _, _, eqScore = G:Equipped(18, spec)
  local best, bestId, known = nil, nil, false
  for _, id in ipairs(e.items or {}) do
    local st = G:Stats(id)
    if st then
      known = true
      local s = G:Score(st, "ranged", spec)
      if not best or s > best then best, bestId = s, id end
    end
  end
  if not known then return nil, e.items and e.items[1], false end
  return math.floor(best - (eqScore or 0) + 0.5), bestId, true
end

-- Status ---------------------------------------------------------------------
-- "done" | "active" | "outgrown" | "ready" | "soon" | "later"
function Q:Status(e, level)
  level = level or self:Level()
  if self:IsDone(e) then return "done" end
  if self:InLog(e) then return "active" end
  local min = self:MinLevel(e)
  if level >= min then
    local gain, _, known = self:Gain(e)
    if known and gain <= 0 then return "outgrown" end
    return "ready"
  end
  if min - level <= self.SOON then return "soon" end
  return "later"
end

function Q:Hidden(e) return DB().questHidden and DB().questHidden[e.key] == true end
function Q:SetHidden(e, on)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.questHidden = PetSkillScoutDB.questHidden or {}
  PetSkillScoutDB.questHidden[e.key] = on and true or nil
end

-- Counts for the tab summary.
function Q:Counts(level)
  local ready, done, total = 0, 0, 0
  for _, e in ipairs(self:List()) do
    total = total + 1
    local s = self:Status(e, level)
    if s == "done" then done = done + 1
    elseif (s == "ready" or s == "active") and not self:Hidden(e) then ready = ready + 1 end
  end
  return ready, done, total
end

-- Filtered list for the tab: "ready" (ready, in the log, soon), "all", "done".
function Q:Rows(filter, level)
  level = level or self:Level()
  local out = {}
  for _, e in ipairs(self:List()) do
    local s = self:Status(e, level)
    local hidden = self:Hidden(e)
    local keep
    if filter == "done" then keep = s == "done"
    elseif filter == "all" then keep = true
    else keep = not hidden and (s == "ready" or s == "active" or s == "soon") end
    if keep then out[#out + 1] = {e = e, status = s, hidden = hidden} end
  end
  return out
end

-- Arrow target to the quest giver (only when the position is known).
function Q:Target(e)
  local info = self:Info(e)
  local mapID = self:ZoneMapID(e)
  if not (mapID and info.x and info.y) then return nil end
  return {name = info.npc or self:Title(e), mapID = mapID, points = {{info.x, info.y}}, zone = info.zone}
end

-- Reminders -----------------------------------------------------------------
function Q:RemindersOn() return DB().questAlert ~= false end

-- Chains worth a reminder now: available, not done, not hidden, not long
-- outgrown, and (when the reward stats are known) an upgrade for you.
function Q:Worth(e, level)
  if self:Hidden(e) then return false end
  local s = self:Status(e, level)
  if s ~= "ready" then return false end
  local gain, _, known = self:Gain(e)
  if known and gain > 0 then return true end
  return level - self:MinLevel(e) <= self.REMIND_SPAN
end

function Q:Line(e)
  local parts = {}
  for _, id in ipairs(e.items or {}) do
    local name, link = self:ItemName(e, id)
    parts[#parts + 1] = link or name
  end
  local text = string.format(L("qAlert"), self:Title(e), self:ZoneName(e), table.concat(parts, " / "))
  if e.req and self:Level() < e.req then text = text .. " (" .. string.format(L("qUseAt"), e.req) .. ")" end
  return text
end

-- Announce chains that became worth doing; each one only once.
-- reason "level": one line per chain (and a screen message);
-- reason "login": one summary line.
function Q:Check(reason, level)
  if not (self:RemindersOn() and self:IsHunter() and PetSkillScoutDB) then return {} end
  level = level or self:Level()
  PetSkillScoutDB.questNotified = PetSkillScoutDB.questNotified or {}
  local seen = PetSkillScoutDB.questNotified
  local fresh = {}
  for _, e in ipairs(self:List()) do
    if not seen[e.key] and self:Worth(e, level) then
      fresh[#fresh + 1] = e
      seen[e.key] = true
    end
  end
  if #fresh == 0 then return fresh end
  if reason == "login" and #fresh > 1 then
    local names = {}
    for _, e in ipairs(fresh) do names[#names + 1] = self:Title(e) end
    PSS:Print(string.format(L("qAlertMany"), table.concat(names, ", ")))
  else
    for _, e in ipairs(fresh) do PSS:Print(self:Line(e)) end
    if reason == "level" and RaidNotice_AddMessage and RaidWarningFrame then
      local info = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]
      Call(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(string.format(L("qAlertShort"), self:Title(fresh[1]))), info)
    end
  end
  if PSS.UI and PSS.UI.Refresh then PSS.UI:Refresh() end
  return fresh
end

-- Quests without a known ID (new in Forever) learn it when you turn them in.
function Q:Learn(questID)
  if not (questID and PetSkillScoutDB) then return end
  local title = self:QuestTitle(questID)
  if not title then return end
  for _, e in ipairs(PSS.QuestData or {}) do
    if (not e.quests or #e.quests == 0) and not e.final and e.name == title then
      PetSkillScoutDB.questLearned = PetSkillScoutDB.questLearned or {}
      PetSkillScoutDB.questLearned[e.key] = questID
    end
  end
end

-- Events ------------------------------------------------------------------------
local function After(sec, fn)
  if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

local function RefreshTab()
  local UI = PSS.UI
  if UI and UI.view == "quests" and UI.Refresh then UI:Refresh() end
end

local ev = CreateFrame("Frame")
Q.frame = ev
for _, name in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
    "QUEST_REMOVED", "GET_ITEM_INFO_RECEIVED"}) do
  pcall(ev.RegisterEvent, ev, name)
end
local loginDone, refreshPending = false, false
ev:SetScript("OnEvent", function(_, event, a1)
  if event == "PLAYER_ENTERING_WORLD" then
    if loginDone then return end
    loginDone = true
    -- Ask the client for reward items first, then check once they are cached.
    for _, e in ipairs(Q:List()) do
      for _, id in ipairs(e.items or {}) do if PSS.Gear then PSS.Gear:Request(id) end end
    end
    After(10, function() Q:Check("login") end)
  elseif event == "PLAYER_LEVEL_UP" then
    local level = tonumber(Plain(a1))
    After(2, function() Q:Check("level", level) end)
  elseif event == "QUEST_TURNED_IN" then
    Q:Learn(tonumber(Plain(a1)))
    After(1, RefreshTab)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if refreshPending then return end
    refreshPending = true
    After(0.5, function() refreshPending = false; RefreshTab() end)
  else
    After(0.5, RefreshTab)
  end
end)
