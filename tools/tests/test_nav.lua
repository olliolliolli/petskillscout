-- Minimap math (3.3.0): offsets from world coordinates, clustered quest pins.
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local Nav, QP = PSS.Nav, PSS.QuestPins
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
-- A 3000 x 2000 yard zone: world X grows to the north, Y to the west.
C_Map = C_Map or {}
CreateVector2D = CreateVector2D or function(x, y) return {x = x, y = y} end
C_Map.GetWorldPosFromMapPos = function(_, v)
  local wx, wy = (1 - v.y) * 2000, (1 - v.x) * 3000
  return 1, {GetXY = function() return wx, wy end}
end
local east, south, exact = Nav:Offset(1438, 0.5, 0.5, 60, 50)
check("exact offset east", exact and math.abs(east - 300) < 0.01 and math.abs(south) < 0.01)
east, south = Nav:Offset(1438, 0.5, 0.5, 50, 40)
check("exact offset north is negative south", math.abs(east) < 0.01 and math.abs(south + 200) < 0.01)
-- Different givers on one spot keep their own pins (spread); one giver is merged.
local W = PSS.QuestWorth
local oldOnMap = W.OnMap
W.OnMap = function() return {
  {id = 1, r = {g = 10, x = 40, y = 40}, rate = {verdict = "ok"}},
  {id = 2, r = {g = 11, x = 40.1, y = 40.1}, rate = {verdict = "great"}},
  {id = 3, r = {g = 12, x = 60, y = 60}, rate = {verdict = "skip"}},
  {id = 4, r = {g = 10, x = 40.3, y = 40}, rate = {verdict = "skip"}},
} end
local groups = QP:Groups(1438, 20)
check("one pin per giver", #groups == 3)
local g10, g11
for _, g in ipairs(groups) do if g.npc == 10 then g10 = g elseif g.npc == 11 then g11 = g end end
check("same giver merged", g10 and #g10.quests == 2)
check("other giver spread", g11 and g11.spread == 1)
W.OnMap = oldOnMap
-- The game's own list of available quests wins over the database.
C_QuestLine = {GetAvailableQuestLines = function(mapID)
  if mapID ~= 1439 then return {} end
  return {{questID = 98013, x = 0.40, y = 0.70, questName = "Swelling Forces"},
          {questID = 999991, x = 0.30, y = 0.30, questName = "Brand New"}}
end}
local list = W:OnMap(1439, 12)
local ids = {}
for _, x in ipairs(list) do ids[x.id] = x end
check("game quests listed", ids[98013] and ids[999991] and #list == 2)
check("game position used", ids[98013] and math.abs(ids[98013].r.x - 40) < 0.01)
check("missing quest kept for the data update", PetSkillScoutDB.gameQuests and PetSkillScoutDB.gameQuests[999991] ~= nil)
C_QuestLine = nil
-- Secret GUIDs (instances / combat) must not raise a string conversion error.
do
  local old = issecretvalue
  issecretvalue = function() return true end
  local ok, v = pcall(PSS.RareTracker and PSS.RareTracker.NpcIDFromGUID or PSS.RarePets.NpcIDFromGUID, "Creature-0-1-2-3-100-5")
  issecretvalue = old
  if ok and v == nil then passes = passes + 1 else fails = fails + 1; print("FAIL secret guid") end
end
check("dark text", PSS.SkinText.IsDark(0.18, 0.1, 0.03) and not PSS.SkinText.IsDark(1, 0.82, 0))
check("fast while moving", PSS.Minimap.Interval(7, false) == PSS.Minimap.FAST and PSS.Minimap.Interval(0, true) == PSS.Minimap.FAST)
check("slow standing", PSS.Minimap.Interval(0, false) == PSS.Minimap.SLOW)
print(string.format("passed %d, failed %d", passes, fails))
