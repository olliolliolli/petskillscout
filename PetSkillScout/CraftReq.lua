-- PetSkillScout - Copyright (c) 2026 DarthRev1. All Rights Reserved.
-- Skill needed for crafted gear, as WoW Forever has it. CraftData comes from
-- Classic item data; Forever changed some recipes (Barbaric Bracers 155 ->
-- 140). The game knows the real value: the pattern tooltip ("Requires
-- Leatherworking (140)") and the trainer window. Both are read and remembered
-- (PetSkillScoutDB.craftReq[item id] = skill), and CraftData is corrected.
local PSS = PetSkillScout
local CR = {}
PSS.CraftReq = CR

local function DB()
  PetSkillScoutDB = PetSkillScoutDB or {}
  PetSkillScoutDB.craftReq = PetSkillScoutDB.craftReq or {}
  return PetSkillScoutDB.craftReq
end

local byId
local function Index()
  if byId then return byId end
  byId = {}
  for _, rec in ipairs(PSS.CraftData or {}) do byId[rec.id] = rec end
  return byId
end

-- Writes the known Forever values into CraftData (kept: rec.sClassic).
function CR:Apply()
  local known = DB()
  for id, rec in pairs(Index()) do
    local need = tonumber(known[id])
    for _, s in ipairs(rec.src or {}) do
      if s.t == "c" then
        s.sClassic = s.sClassic or s.s
        s.s = need or s.sClassic
      end
    end
  end
end

function CR:Learn(itemID, skill)
  itemID, skill = tonumber(itemID), tonumber(skill)
  if not itemID or not skill or not Index()[itemID] then return end
  local known = DB()
  if known[itemID] ~= skill then
    known[itemID] = skill
    self:Apply()
    if PSS.UI and PSS.UI.view == "gear" and PSS.UI.RefreshView then pcall(PSS.UI.RefreshView, PSS.UI) end
  end
end

-- "Requires %s (%d)" of the client language as a Lua pattern.
local function ReqPattern()
  local t = type(ITEM_MIN_SKILL) == "string" and ITEM_MIN_SKILL or "Requires %s (%d)"
  t = t:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
  t = t:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
  return "^" .. t:gsub("\1", ".+"):gsub("\2", "(%%d+)") .. "$"
end

local function TooltipSkill(patternID)
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, patternID)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local pat = ReqPattern()
  for _, line in ipairs(data.lines) do
    local text = line.leftText
    if type(text) == "string" and not (PSS.IsSecret and PSS.IsSecret(text)) then
      local n = text:match(pat)
      if n then return tonumber(n) end
    end
  end
end

-- Patterns are read a few at a time; uncached items are asked for and tried
-- again on the next pass.
local queue, passes = {}, 0
local function Fill()
  queue = {}
  for item, pattern in pairs(PSS.CraftPatterns or {}) do queue[#queue + 1] = {item, pattern} end
end

local Step
local function StepRaw()
  for _ = 1, 6 do
    local e = table.remove(queue)
    if not e then
      passes = passes + 1
      if passes < 3 then
        Fill()
        if C_Timer then C_Timer.After(20, Step) end
      end
      return
    end
    local skill = TooltipSkill(e[2])
    if skill then
      CR:Learn(e[1], skill)
      PSS.CraftPatterns[e[1]] = nil
    elseif passes == 0 and C_Item and C_Item.RequestLoadItemDataByID then
      pcall(C_Item.RequestLoadItemDataByID, e[2])
    end
  end
  if C_Timer then C_Timer.After(0.3, Step) end
end

Step = PSS:Timed("CraftReq pattern scan", StepRaw)

-- Trainer window: the skill each recipe needs, straight from the trainer.
local function ScanTrainer()
  if type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceSkillReq) ~= "function" then return end
  local ok, n = pcall(GetNumTrainerServices)
  if not ok or type(n) ~= "number" then return end
  for i = 1, n do
    local ok2, link = pcall(GetTrainerServiceItemLink, i)
    local id = ok2 and type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id and Index()[id] then
      local ok3, _, rank = pcall(GetTrainerServiceSkillReq, i)
      if ok3 and tonumber(rank) then CR:Learn(id, rank) end
    end
  end
end

local f = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "TRAINER_SHOW", "TRAINER_UPDATE"}) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    CR:Apply()
    -- Every login: patterns are read again, so a later Forever change is seen.
    Fill()
    if C_Timer then C_Timer.After(15, Step) end
  else
    pcall(ScanTrainer)
  end
end)
