-- Hunter achievements and the score used for guild / realm rankings.
-- Everything is computed from what the addon already records; unlocking an
-- achievement only shows a message.
local PSS = PetSkillScout
PSS.Achieve = {}
local A = PSS.Achieve

local function Now() return time and time() or 0 end
local function DB(key)
  PetSkillScoutDB[key] = PetSkillScoutDB[key] or {}
  return PetSkillScoutDB[key]
end

local function Count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function Looks() return PSS.Collection and (PSS.Collection:Counts()) or 0 end
local function LooksTotal() local _, t = PSS.Collection:Counts() return t end
local function RaresTamed() return Count(PetSkillScoutDB.rareCollected) end
local function RaresSeen() return Count(PetSkillScoutDB.rareSeen) end
local function Families() return PSS.Collection and PSS.Collection:FamiliesTamed() or 0 end
local function FamilyTotal() return PSS.Collection and PSS.Collection:FamilyTotal() or 18 end
local function RouteRanks() return PetSkillScoutDB.routeLearned or 0 end
local function Reports() return PetSkillScoutDB.reportsSent or 0 end
local function QueueTames() return PetSkillScoutDB.queueTames or 0 end
local function CardsShared() return PetSkillScoutDB.cardsShared or 0 end

local function CompleteFamilies()
  local C = PSS.Collection
  if not C then return 0 end
  C:Build()
  local n = 0
  for family in pairs(C.families) do
    local have, total = C:FamilyCounts(family)
    if total > 0 and have >= total then n = n + 1 end
  end
  return n
end

local function LongestFriendship()
  local best = 0
  for _, rec in pairs(PetSkillScoutDB.petLog or {}) do
    local d = PSS.Collection:DaysTogether(rec) or 0
    if d > best then best = d end
  end
  return best
end

local function MaxRanks()
  local n = 0
  local known = PetSkillScoutDB.knownRanks or {}
  local pet = PSS.MyPet
  local have = {}
  for k, v in pairs(known) do have[k] = tonumber(v) end
  if pet and pet.active then
    for _, s in ipairs(pet.spells or {}) do
      if s.key and s.rank and s.rank > (have[s.key] or 0) then have[s.key] = s.rank end
    end
  end
  for key, rank in pairs(have) do
    local ranks = PSS.Ranks and PSS.Ranks[key]
    if ranks and #ranks > 1 and rank >= #ranks then n = n + 1 end
  end
  return n
end

-- {id, icon, points, value function, goal (number or function)}
A.LIST = {
  {"look10", "INV_Misc_Book_09", 10, Looks, 10},
  {"look25", "INV_Misc_Book_09", 20, Looks, 25},
  {"look50", "INV_Misc_Book_11", 40, Looks, 50},
  {"look100", "INV_Misc_Book_11", 80, Looks, 100},
  {"lookAll", "INV_Misc_Book_07", 200, Looks, LooksTotal},
  {"family1", "Ability_Hunter_BeastTaming", 15, CompleteFamilies, 1},
  {"family5", "Ability_Hunter_BeastTaming", 60, CompleteFamilies, 5},
  {"families", "Ability_Hunter_BeastCall", 50, Families, FamilyTotal},
  {"rare1", "Ability_Hunter_Pet_Wolf", 10, RaresTamed, 1},
  {"rare5", "Ability_Hunter_Pet_Cat", 30, RaresTamed, 5},
  {"rare10", "Ability_Hunter_Pet_Raptor", 60, RaresTamed, 10},
  {"rare25", "Ability_Hunter_Pet_Bear", 120, RaresTamed, 25},
  {"seen20", "INV_Misc_Spyglass_02", 15, RaresSeen, 20},
  {"scout25", "INV_Misc_Spyglass_03", 25, Reports, 25},
  {"route10", "Ability_Hunter_Pathfinding", 20, RouteRanks, 10},
  {"maxRank", "Ability_Druid_Rake", 30, MaxRanks, 1},
  {"friend30", "INV_ValentinesCard02", 30, LongestFriendship, 30},
  {"friend100", "INV_ValentinesCard01", 60, LongestFriendship, 100},
  {"queue1", "INV_Misc_PocketWatch_01", 20, QueueTames, 1},
  {"share5", "INV_Letter_15", 10, CardsShared, 5},
}

local function Goal(def)
  local g = def[5]
  if type(g) == "function" then g = g() end
  return math.max(1, tonumber(g) or 1)
end

-- value, goal, unlocked time
function A:Progress(def)
  local ok, value = pcall(def[4])
  value = ok and tonumber(value) or 0
  local unlocked = PetSkillScoutDB and PetSkillScoutDB.achieved and PetSkillScoutDB.achieved[def[1]]
  return value, Goal(def), unlocked
end

function A:Score()
  local score = 0
  local done = PetSkillScoutDB and PetSkillScoutDB.achieved or {}
  for _, def in ipairs(self.LIST) do if done[def[1]] then score = score + def[3] end end
  return score
end

-- score, looks, rares tamed, families
function A:Stats()
  if not PetSkillScoutDB then return 0, 0, 0, 0 end
  return self:Score(), Looks(), RaresTamed(), Families()
end

function A:Unlocked()
  return Count(PetSkillScoutDB and PetSkillScoutDB.achieved)
end

local function Toast(def)
  local name = PSS:L("ach_" .. def[1])
  local text = string.format(PSS:L("achUnlocked"), name, def[3])
  PSS:Print(text)
  if RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(text), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
  end
  if PlaySound then pcall(PlaySound, 12891) end
end

-- Unlocks what is reached. The first run only records, so old progress does
-- not flood the screen with messages.
function A:Check()
  if not PetSkillScoutDB then return end
  local done = DB("achieved")
  local quiet = not PetSkillScoutDB.achievedInit
  local new = false
  for _, def in ipairs(self.LIST) do
    if not done[def[1]] then
      local value, goal = self:Progress(def)
      if value >= goal then
        done[def[1]] = Now()
        new = true
        if not quiet then Toast(def) end
      end
    end
  end
  PetSkillScoutDB.achievedInit = true
  if new and PSS.Net then PSS.Net:Hello() end
  if new and PSS.UI and PSS.UI.view == "collection" and PSS.UI.UpdateCollection then PSS.UI:UpdateCollection() end
end

A.frame = CreateFrame("Frame")
A.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local tick = 0
A.frame:SetScript("OnEvent", function() tick = 25 end)
A.frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + (elapsed or 0)
  if tick < 30 then return end
  tick = 0
  pcall(A.Check, A)
end)
A.frame.pssKey = "Achieve"
PSS:Every(A.frame, 5)
