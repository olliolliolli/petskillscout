dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {}; PSS:InitializeDB()
function UnitRace() return "Human", "Human", 1 end
function UnitClass() return "Hunter", "HUNTER", 3 end
MOCK.level = 30
local W = PSS.QuestWorth
W:Index()
local maps = {}
for m, list in pairs(W.byMap) do maps[#maps + 1] = {m, #list} end
table.sort(maps, function(a, b) return a[2] > b[2] end)
for i = 1, 3 do
  local t = os.clock()
  local g = PSS.QuestPins:Groups(maps[i][1], 30)
  print(string.format("map %d: %d quests, %d pin groups, %.1f ms", maps[i][1], maps[i][2], #g, (os.clock() - t) * 1000))
end
local t = os.clock()
W.byMap = nil; W:Index()
print(string.format("index %.1f ms", (os.clock() - t) * 1000))
