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
-- Clustering: two givers 0.5 % apart share one pin.
local W = PSS.QuestWorth
local oldOnMap = W.OnMap
W.OnMap = function() return {
  {id = 1, r = {g = 10, x = 40, y = 40}, rate = {verdict = "ok"}},
  {id = 2, r = {g = 11, x = 40.5, y = 40.2}, rate = {verdict = "great"}},
  {id = 3, r = {g = 12, x = 60, y = 60}, rate = {verdict = "skip"}},
} end
local groups = QP:Groups(1438, 20)
check("close givers merged", #groups == 2 and #groups[1].quests == 2 and groups[1].best == "great")
W.OnMap = oldOnMap
print(string.format("passed %d, failed %d", passes, fails))
