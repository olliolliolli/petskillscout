-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Optional, off by default: abandons quests in your log that the game shows
-- grey (too low for you). Finished quests, hunter chain quests, hidden and
-- campaign quests stay. One quest at a time, never in combat or instances.
-- Every abandoned quest is printed and kept in PetSkillScoutDB.questDropped.
local PSS = PetSkillScout
PSS.QuestCleanup = {}
local C = PSS.QuestCleanup
C.GAP = 2

function C:On() return PetSkillScoutDB and PetSkillScoutDB.questDropGrey == true end

local function Flag(fn, ...)
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, ...)
  return ok and PSS.Plain(v) and true or false
end

-- Nil when the client cannot tell: then nothing is abandoned.
function C.IsGrey(id, level)
  local api = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer
  local trivial = Enum and Enum.RelativeContentDifficulty and Enum.RelativeContentDifficulty.Trivial
  if api and trivial ~= nil then
    local ok, v = pcall(api, id)
    if ok and PSS.Plain(v) ~= nil then return v == trivial end
  end
  if GetQuestDifficultyColor and type(level) == "number" and level > 0 then
    local ok, c = pcall(GetQuestDifficultyColor, level)
    if ok and type(c) == "table" and type(c.r) == "number" then
      return math.abs(c.r - c.g) < 0.02 and math.abs(c.g - c.b) < 0.02 and c.r <= 0.6
    end
  end
  return nil
end

-- Quests of the hunter chains are never touched.
function C.Protected(id)
  for _, e in ipairs(PSS.QuestData or {}) do
    for _, q in ipairs(e.quests or {}) do
      if q == id or (type(q) == "table" and (q.id == id or q[1] == id or q[2] == id)) then return true end
    end
  end
  return false
end

function C.Keep(info, done)
  return info.isHeader or info.isHidden or info.isTask or info.campaignID ~= nil or done or C.Protected(info.questID)
end

function C:Next()
  local api = C_QuestLog
  if not (api and api.GetNumQuestLogEntries and api.GetInfo) then return nil end
  local n = tonumber(PSS.Plain(api.GetNumQuestLogEntries())) or 0
  for i = 1, n do
    local ok, info = pcall(api.GetInfo, i)
    if ok and type(info) == "table" and info.questID and not PSS.IsSecret(info.questID) then
      local done = api.IsComplete and select(2, pcall(api.IsComplete, info.questID))
      if not self.Keep(info, done == true) and self.IsGrey(info.questID, info.level) == true then return info end
    end
  end
end

function C:Drop(info)
  local api = C_QuestLog
  if not (api.SetSelectedQuest and api.SetAbandonQuest and api.AbandonQuest) then return false end
  api.SetSelectedQuest(info.questID)
  api.SetAbandonQuest()
  api.AbandonQuest()
  local db = PetSkillScoutDB
  db.questDropped = db.questDropped or {}
  db.questDropped[info.questID] = time and time() or 0
  PSS:Print(string.format(PSS:L("questDropped"), tostring(info.title), tostring(info.level)))
  return true
end

function C:Run()
  if not self:On() or Flag(InCombatLockdown) or Flag(IsInInstance) then return end
  local info = self:Next()
  if info and pcall(self.Drop, self, info) then
    if C_Timer and C_Timer.After then C_Timer.After(self.GAP, function() C:Run() end) end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "QUEST_ACCEPTED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function()
  if C:On() then PSS:Soon("quest-cleanup", function() pcall(C.Run, C) end, 3) end
end)
